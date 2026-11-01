import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../expenses/data/providers/expenses_providers.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/payroll.dart';
import '../models/worker.dart';
import '../repositories/offline_payroll_repository.dart';
import '../repositories/payroll_repository.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  final remote = SupabasePayrollRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflinePayrollRepository(remote, offline);
});

final workersProvider = FutureProvider<List<Worker>>((ref) {
  return ref.watch(payrollRepositoryProvider).fetchWorkers();
});

/// Workers still on the payroll.
final activeWorkersProvider = Provider<List<Worker>>((ref) {
  return [
    for (final worker in ref.watch(workersProvider).valueOrNull ?? const [])
      if (worker.isActive) worker,
  ];
});

/// Worker id → rate (owners and admins; empty for anyone else).
final workerRatesProvider = FutureProvider.autoDispose<Map<String, num>>((ref) {
  return ref.watch(payrollRepositoryProvider).fetchRates();
});

/// The day the Attendance and Bags tabs show; today by default.
final payDayProvider = StateProvider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);

final attendanceForDayProvider = FutureProvider<List<AttendanceMark>>((ref) {
  final day = ref.watch(payDayProvider);
  return ref
      .watch(payrollRepositoryProvider)
      .fetchAttendance(from: day, to: nextDay(day));
});

final bagCountsForDayProvider = FutureProvider<List<BagCount>>((ref) {
  final day = ref.watch(payDayProvider);
  return ref
      .watch(payrollRepositoryProvider)
      .fetchBagCounts(from: day, to: nextDay(day));
});

final advancesProvider = FutureProvider.autoDispose<List<SalaryAdvance>>((ref) {
  return ref.watch(payrollRepositoryProvider).fetchAdvances();
});

/// The payroll month shown (first day); last month by default, since a
/// month is usually paid just after it ends.
final payrollMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 1);
});

final payrollProvider = FutureProvider.autoDispose<Payroll?>((ref) {
  return ref
      .watch(payrollRepositoryProvider)
      .fetchPayroll(ref.watch(payrollMonthProvider));
});

/// Every write on the Workers & pay screens.
class PayrollActionController extends ActionController {
  PayrollActionController(this._ref);

  final Ref _ref;

  PayrollRepository get _repository => _ref.read(payrollRepositoryProvider);

  Future<bool> _run(
    Future<void> Function() action,
    List<ProviderOrFamily> refresh,
  ) async {
    final done = await guard(() async {
      await action();
      for (final provider in refresh) {
        _ref.invalidate(provider);
      }
      return true;
    });
    return done ?? false;
  }

  Future<bool> saveWorker(Worker worker, {required num rate}) => _run(
    () => _repository.saveWorker(worker, rate: rate),
    [workersProvider, workerRatesProvider],
  );

  Future<bool> recordAttendance(
    DateTime date,
    Map<String, AttendanceStatus> marks,
  ) => _run(() => _repository.recordAttendance(date, marks), [
    attendanceForDayProvider,
  ]);

  Future<bool> recordBagCounts(DateTime date, Map<String, int> bags) => _run(
    () => _repository.recordBagCounts(date, bags),
    [bagCountsForDayProvider],
  );

  Future<bool> giveAdvance({
    required String workerId,
    required num amount,
    required PaymentChannel method,
    String? note,
  }) => _run(
    () => _repository.giveAdvance(
      workerId: workerId,
      amount: amount,
      method: method,
      note: note,
    ),
    [advancesProvider, expensesProvider],
  );

  Future<bool> preparePayroll(DateTime month) =>
      _run(() => _repository.preparePayroll(month), [payrollProvider]);

  Future<bool> adjustLine(String lineId, num adjustment, String? note) => _run(
    () => _repository.adjustLine(lineId, adjustment, note),
    [payrollProvider],
  );

  Future<bool> payPayroll(String payrollId, PaymentChannel method) => _run(
    () => _repository.payPayroll(payrollId, method),
    [payrollProvider, advancesProvider, expensesProvider],
  );
}

final payrollActionControllerProvider =
    StateNotifierProvider.autoDispose<
      PayrollActionController,
      AsyncValue<void>
    >((ref) => PayrollActionController(ref));
