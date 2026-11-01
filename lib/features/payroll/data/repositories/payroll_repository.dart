import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/query_range.dart';
import '../models/payroll.dart';
import '../models/worker.dart';

/// Workers, attendance, bag counts, advances and payroll for the current
/// organization. Rates, advances and payroll only load for owners and
/// admins (enforced by RLS); for others they come back empty.
abstract class PayrollRepository {
  Future<List<Worker>> fetchWorkers();

  /// Adds the worker (or updates it when [Worker.id] is set) and its rate.
  Future<void> saveWorker(Worker worker, {required num rate});

  /// Worker id → rate.
  Future<Map<String, num>> fetchRates();

  Future<List<AttendanceMark>> fetchAttendance({
    required DateTime from,
    required DateTime to,
  });
  Future<void> recordAttendance(
    DateTime date,
    Map<String, AttendanceStatus> marks,
  );

  Future<List<BagCount>> fetchBagCounts({
    required DateTime from,
    required DateTime to,
  });
  Future<void> recordBagCounts(DateTime date, Map<String, int> bags);

  Future<List<SalaryAdvance>> fetchAdvances();
  Future<void> giveAdvance({
    required String workerId,
    required num amount,
    required PaymentChannel method,
    String? note,
  });

  /// The month's payroll, or null if it hasn't been prepared.
  Future<Payroll?> fetchPayroll(DateTime month);
  Future<void> preparePayroll(DateTime month);
  Future<void> adjustLine(String lineId, num adjustment, String? note);
  Future<void> payPayroll(String payrollId, PaymentChannel method);
}

String _day(DateTime date) => date.toIso8601String().split('T').first;

class SupabasePayrollRepository implements PayrollRepository {
  SupabasePayrollRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static Map<String, dynamic> attendancePayload(
    DateTime date,
    Map<String, AttendanceStatus> marks,
  ) => {
    'date': _day(date),
    'entries': [
      for (final entry in marks.entries)
        {'worker_id': entry.key, 'status': entry.value.dbValue},
    ],
  };

  static Map<String, dynamic> bagCountsPayload(
    DateTime date,
    Map<String, int> bags,
  ) => {
    'date': _day(date),
    'entries': [
      for (final entry in bags.entries)
        {'worker_id': entry.key, 'bags': entry.value},
    ],
  };

  Future<void> _rpc(String name, Map<String, dynamic> params) =>
      _client.rpc(name, params: {'p_tenant_id': _tenantId, ...params});

  @override
  Future<List<Worker>> fetchWorkers() async {
    final rows = await _client
        .from('workers')
        .select()
        .eq('tenant_id', _tenantId)
        .order('name');
    return [
      for (final row in rows as List)
        Worker.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> saveWorker(Worker worker, {required num rate}) async {
    final String id;
    if (worker.id.isEmpty) {
      final row = await _client
          .from('workers')
          .insert({'tenant_id': _tenantId, ...worker.toWriteJson()})
          .select('id')
          .single();
      id = row['id'] as String;
    } else {
      id = worker.id;
      await _client
          .from('workers')
          .update(worker.toWriteJson())
          .eq('tenant_id', _tenantId)
          .eq('id', id);
    }
    await _client.from('worker_rates').upsert({
      'tenant_id': _tenantId,
      'worker_id': id,
      'rate': rate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, num>> fetchRates() async {
    final rows = await _client
        .from('worker_rates')
        .select('worker_id, rate')
        .eq('tenant_id', _tenantId);
    return {
      for (final row in rows as List)
        (row as Map)['worker_id'] as String: row['rate'] as num,
    };
  }

  @override
  Future<List<AttendanceMark>> fetchAttendance({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('attendance')
        .select()
        .eq('tenant_id', _tenantId)
        .inRange('date', from: from, to: to, dateOnly: true);
    return [
      for (final row in rows as List)
        AttendanceMark.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordAttendance(
    DateTime date,
    Map<String, AttendanceStatus> marks,
  ) {
    final payload = attendancePayload(date, marks);
    return _rpc('record_attendance', {
      'p_date': payload['date'],
      'p_entries': payload['entries'],
    });
  }

  @override
  Future<List<BagCount>> fetchBagCounts({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('bag_counts')
        .select()
        .eq('tenant_id', _tenantId)
        .inRange('date', from: from, to: to, dateOnly: true);
    return [
      for (final row in rows as List)
        BagCount.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> recordBagCounts(DateTime date, Map<String, int> bags) {
    final payload = bagCountsPayload(date, bags);
    return _rpc('record_bag_counts', {
      'p_date': payload['date'],
      'p_entries': payload['entries'],
    });
  }

  @override
  Future<List<SalaryAdvance>> fetchAdvances() async {
    final rows = await _client
        .from('salary_advances')
        .select()
        .eq('tenant_id', _tenantId)
        .order('date', ascending: false);
    return [
      for (final row in rows as List)
        SalaryAdvance.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> giveAdvance({
    required String workerId,
    required num amount,
    required PaymentChannel method,
    String? note,
  }) => _rpc('give_advance', {
    'p_worker_id': workerId,
    'p_date': _day(DateTime.now()),
    'p_amount': amount,
    'p_method': method.name,
    'p_note': note,
  });

  @override
  Future<Payroll?> fetchPayroll(DateTime month) async {
    final row = await _client
        .from('payrolls')
        .select('*, payroll_lines(*, workers(name))')
        .eq('tenant_id', _tenantId)
        .eq('month', _day(DateTime(month.year, month.month)))
        .maybeSingle();
    return row == null ? null : Payroll.fromJson(row);
  }

  @override
  Future<void> preparePayroll(DateTime month) => _rpc('prepare_payroll', {
    'p_month': _day(DateTime(month.year, month.month)),
  });

  @override
  Future<void> adjustLine(String lineId, num adjustment, String? note) => _rpc(
    'adjust_payroll_line',
    {'p_line_id': lineId, 'p_adjustment': adjustment, 'p_note': note},
  );

  @override
  Future<void> payPayroll(String payrollId, PaymentChannel method) =>
      _rpc('pay_payroll', {'p_payroll_id': payrollId, 'p_method': method.name});
}
