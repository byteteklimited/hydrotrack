import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/query_range.dart';
import '../models/machine.dart';
import '../models/machine_report.dart';

/// Machines, their maintenance, breakdowns and diesel, for the current
/// organization. Costs are posted as expenses by the server.
abstract class MachinesRepository {
  /// Every machine, retired ones included, by name.
  Future<List<Machine>> fetchMachines();
  Future<void> saveMachine({
    required String name,
    required MachineKind kind,
    String? id,
    bool? isActive,
  });

  Future<List<MaintenanceTask>> fetchTasks();
  Future<void> saveTask({
    required String machineId,
    required String name,
    required int everyDays,
    String? id,
    bool? isActive,
  });
  Future<void> recordMaintenance({
    required String taskId,
    required DateTime doneOn,
    num cost = 0,
    PaymentChannel? method,
    String? note,
  });

  /// Open breakdowns, and any that started on or after [since].
  Future<List<Breakdown>> fetchBreakdowns({required DateTime since});
  Future<void> reportBreakdown({
    required String machineId,
    required DateTime startedAt,
    required String cause,
  });
  Future<void> endBreakdown({
    required String breakdownId,
    required DateTime endedAt,
    num repairCost = 0,
    PaymentChannel? method,
    String? note,
  });

  Future<List<DieselLog>> fetchDieselLogs({required DateTime since});
  Future<void> recordDiesel({
    required String machineId,
    required DateTime date,
    required num litres,
    required num cost,
    required PaymentChannel method,
    num? runHours,
    String? note,
  });

  /// Days [from] up to (not including) [to]. Needs internet.
  Future<MachineReport> fetchReport({
    required DateTime from,
    required DateTime to,
  });
}

String _day(DateTime date) => date.toIso8601String().split('T').first;

class SupabaseMachinesRepository implements MachinesRepository {
  SupabaseMachinesRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  // Payloads: what each RPC takes without `p_`, also the offline record.

  static Map<String, dynamic> maintenancePayload({
    required String taskId,
    required DateTime doneOn,
    required num cost,
    PaymentChannel? method,
    String? note,
  }) => {
    'task_id': taskId,
    'done_on': _day(doneOn),
    'cost': cost,
    'method': method?.name,
    'note': note,
  };

  static Map<String, dynamic> breakdownPayload({
    required String? id,
    required String machineId,
    required DateTime startedAt,
    required String cause,
  }) => {
    'id': id,
    'machine_id': machineId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'cause': cause,
  };

  static Map<String, dynamic> breakdownEndPayload({
    required String breakdownId,
    required DateTime endedAt,
    required num repairCost,
    PaymentChannel? method,
    String? note,
  }) => {
    'breakdown_id': breakdownId,
    'ended_at': endedAt.toUtc().toIso8601String(),
    'repair_cost': repairCost,
    'method': method?.name,
    'note': note,
  };

  static Map<String, dynamic> dieselPayload({
    required String machineId,
    required DateTime date,
    required num litres,
    required num cost,
    required PaymentChannel method,
    num? runHours,
    String? note,
  }) => {
    'machine_id': machineId,
    'date': _day(date),
    'litres': litres,
    'cost': cost,
    'method': method.name,
    'run_hours': runHours,
    'note': note,
  };

  Future<void> _rpc(
    String name,
    Map<String, dynamic> payload, {
    Map<String, String> rename = const {},
  }) => _client.rpc(
    name,
    params: {
      'p_tenant_id': _tenantId,
      for (final entry in payload.entries)
        'p_${rename[entry.key] ?? entry.key}': entry.value,
    },
  );

  Future<List<T>> _rows<T>(
    Future<dynamic> query,
    T Function(Map<String, dynamic>) fromJson,
  ) async => [
    for (final row in await query as List)
      fromJson(row as Map<String, dynamic>),
  ];

  @override
  Future<List<Machine>> fetchMachines() => _rows(
    _client.from('machines').select().eq('tenant_id', _tenantId).order('name'),
    Machine.fromJson,
  );

  @override
  Future<void> saveMachine({
    required String name,
    required MachineKind kind,
    String? id,
    bool? isActive,
  }) {
    final values = {'name': name, 'kind': kind.name, 'is_active': ?isActive};
    if (id == null) {
      return _client.from('machines').insert({
        'tenant_id': _tenantId,
        ...values,
      });
    }
    return _client
        .from('machines')
        .update(values)
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<List<MaintenanceTask>> fetchTasks() => _rows(
    _client.from('maintenance_tasks').select().eq('tenant_id', _tenantId),
    MaintenanceTask.fromJson,
  );

  @override
  Future<void> saveTask({
    required String machineId,
    required String name,
    required int everyDays,
    String? id,
    bool? isActive,
  }) {
    final values = {
      'machine_id': machineId,
      'name': name,
      'every_days': everyDays,
      'is_active': ?isActive,
    };
    if (id == null) {
      return _client.from('maintenance_tasks').insert({
        'tenant_id': _tenantId,
        ...values,
      });
    }
    return _client
        .from('maintenance_tasks')
        .update(values)
        .eq('tenant_id', _tenantId)
        .eq('id', id);
  }

  @override
  Future<void> recordMaintenance({
    required String taskId,
    required DateTime doneOn,
    num cost = 0,
    PaymentChannel? method,
    String? note,
  }) => _rpc(
    'record_maintenance',
    maintenancePayload(
      taskId: taskId,
      doneOn: doneOn,
      cost: cost,
      method: method,
      note: note,
    ),
  );

  @override
  Future<List<Breakdown>> fetchBreakdowns({required DateTime since}) => _rows(
    _client
        .from('breakdowns')
        .select('*, profiles!reported_by(full_name)')
        .eq('tenant_id', _tenantId)
        .or(
          'ended_at.is.null,started_at.gte.${since.toUtc().toIso8601String()}',
        )
        .order('started_at', ascending: false),
    Breakdown.fromJson,
  );

  @override
  Future<void> reportBreakdown({
    required String machineId,
    required DateTime startedAt,
    required String cause,
  }) => _rpc(
    'report_breakdown',
    breakdownPayload(
      id: null,
      machineId: machineId,
      startedAt: startedAt,
      cause: cause,
    ),
  );

  @override
  Future<void> endBreakdown({
    required String breakdownId,
    required DateTime endedAt,
    num repairCost = 0,
    PaymentChannel? method,
    String? note,
  }) => _rpc(
    'end_breakdown',
    breakdownEndPayload(
      breakdownId: breakdownId,
      endedAt: endedAt,
      repairCost: repairCost,
      method: method,
      note: note,
    ),
  );

  @override
  Future<List<DieselLog>> fetchDieselLogs({required DateTime since}) => _rows(
    _client
        .from('diesel_logs')
        .select('*, profiles!recorded_by(full_name)')
        .eq('tenant_id', _tenantId)
        .inRange('date', from: since, dateOnly: true)
        .order('date', ascending: false),
    DieselLog.fromJson,
  );

  @override
  Future<void> recordDiesel({
    required String machineId,
    required DateTime date,
    required num litres,
    required num cost,
    required PaymentChannel method,
    num? runHours,
    String? note,
  }) => _rpc(
    'record_diesel',
    dieselPayload(
      machineId: machineId,
      date: date,
      litres: litres,
      cost: cost,
      method: method,
      runHours: runHours,
      note: note,
    ),
  );

  @override
  Future<MachineReport> fetchReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.rpc(
      'machine_report',
      params: {
        'p_tenant_id': _tenantId,
        'p_from': _day(from),
        'p_to': _day(to),
      },
    );
    return MachineReport.fromJson(json as Map<String, dynamic>);
  }
}
