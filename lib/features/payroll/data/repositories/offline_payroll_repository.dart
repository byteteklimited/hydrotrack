import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/payroll.dart';
import '../models/worker.dart';
import 'payroll_repository.dart';

/// On a device set up for offline use: attendance and bag counts are
/// saved on the device first, then sent. Pay (rates, advances, payroll)
/// is never kept on devices and needs internet.
class OfflinePayrollRepository implements PayrollRepository {
  OfflinePayrollRepository(this._remote, this._offline);

  final PayrollRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Worker>> fetchWorkers() => _offline.read(
    remote: _remote.fetchWorkers,
    local: (snapshot) =>
        snapshot.rows('workers').map(Worker.fromJson).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<void> saveWorker(Worker worker, {required num rate}) =>
      _offline.online(() => _remote.saveWorker(worker, rate: rate));

  @override
  Future<Map<String, num>> fetchRates() => _offline.online(_remote.fetchRates);

  @override
  Future<List<AttendanceMark>> fetchAttendance({
    required DateTime from,
    required DateTime to,
  }) => _offline.read(
    remote: () => _remote.fetchAttendance(from: from, to: to),
    local: (snapshot) => snapshot
        .rows('attendance')
        .map(AttendanceMark.fromJson)
        .where((mark) => isInRange(mark.date, from: from, to: to))
        .toList(),
  );

  @override
  Future<void> recordAttendance(
    DateTime date,
    Map<String, AttendanceStatus> marks,
  ) => _offline.record(
    OperationType.attendance,
    SupabasePayrollRepository.attendancePayload(date, marks),
  );

  @override
  Future<List<BagCount>> fetchBagCounts({
    required DateTime from,
    required DateTime to,
  }) => _offline.read(
    remote: () => _remote.fetchBagCounts(from: from, to: to),
    local: (snapshot) => snapshot
        .rows('bag_counts')
        .map(BagCount.fromJson)
        .where((count) => isInRange(count.date, from: from, to: to))
        .toList(),
  );

  @override
  Future<void> recordBagCounts(DateTime date, Map<String, int> bags) =>
      _offline.record(
        OperationType.bagCounts,
        SupabasePayrollRepository.bagCountsPayload(date, bags),
      );

  @override
  Future<List<SalaryAdvance>> fetchAdvances() =>
      _offline.online(_remote.fetchAdvances);

  @override
  Future<void> giveAdvance({
    required String workerId,
    required num amount,
    required PaymentChannel method,
    String? note,
  }) => _offline.online(
    () => _remote.giveAdvance(
      workerId: workerId,
      amount: amount,
      method: method,
      note: note,
    ),
  );

  @override
  Future<Payroll?> fetchPayroll(DateTime month) =>
      _offline.online(() => _remote.fetchPayroll(month));

  @override
  Future<void> preparePayroll(DateTime month) =>
      _offline.online(() => _remote.preparePayroll(month));

  @override
  Future<void> adjustLine(String lineId, num adjustment, String? note) =>
      _offline.online(() => _remote.adjustLine(lineId, adjustment, note));

  @override
  Future<void> payPayroll(String payrollId, PaymentChannel method) =>
      _offline.online(() => _remote.payPayroll(payrollId, method));
}
