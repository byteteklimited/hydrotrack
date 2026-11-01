import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../expenses/data/providers/expenses_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/machine.dart';
import '../models/machine_report.dart';
import '../repositories/machines_repository.dart';
import '../repositories/offline_machines_repository.dart';

/// How far back breakdowns and diesel are listed.
const machineHistoryDays = 30;

final machinesRepositoryProvider = Provider<MachinesRepository>((ref) {
  final remote = SupabaseMachinesRepository(ref.watch(currentTenantIdProvider));
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineMachinesRepository(remote, offline);
});

final machinesProvider = FutureProvider<List<Machine>>((ref) {
  return ref.watch(machinesRepositoryProvider).fetchMachines();
});

/// Machines still in use, for pick lists.
final activeMachinesProvider = Provider<AsyncValue<List<Machine>>>((ref) {
  return ref
      .watch(machinesProvider)
      .whenData(
        (machines) => [
          for (final m in machines)
            if (m.isActive) m,
        ],
      );
});

final maintenanceTasksProvider = FutureProvider<List<MaintenanceTask>>((ref) {
  return ref.watch(machinesRepositoryProvider).fetchTasks();
});

/// Active tasks on active machines due within [MaintenanceTask.dueSoonDays]
/// or overdue, soonest first.
final maintenanceDueProvider = Provider<List<MaintenanceTask>>((ref) {
  final tasks = ref.watch(maintenanceTasksProvider).valueOrNull ?? const [];
  final machines = ref.watch(machinesProvider).valueOrNull ?? const [];
  final active = {
    for (final m in machines)
      if (m.isActive) m.id,
  };
  final today = DateTime.now();
  return [
    for (final task in tasks)
      if (task.isActive &&
          active.contains(task.machineId) &&
          task.daysUntilDue(today) <= MaintenanceTask.dueSoonDays)
        task,
  ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
});

DateTime _historyStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - machineHistoryDays);
}

final breakdownsProvider = FutureProvider<List<Breakdown>>((ref) {
  return ref
      .watch(machinesRepositoryProvider)
      .fetchBreakdowns(since: _historyStart());
});

final dieselLogsProvider = FutureProvider<List<DieselLog>>((ref) {
  return ref
      .watch(machinesRepositoryProvider)
      .fetchDieselLogs(since: _historyStart());
});

/// This month so far; null when it can't be loaded (e.g. offline).
final machineReportProvider = FutureProvider<MachineReport?>((ref) async {
  final now = DateTime.now();
  try {
    return await ref
        .watch(machinesRepositoryProvider)
        .fetchReport(
          from: DateTime(now.year, now.month),
          to: DateTime(now.year, now.month, now.day + 1),
        );
  } catch (_) {
    return null;
  }
});

/// Every write on the Machines screens.
class MachinesActionController extends ActionController {
  MachinesActionController(this._ref);

  final Ref _ref;

  MachinesRepository get _repository => _ref.read(machinesRepositoryProvider);

  Future<bool> _run(
    Future<void> Function() action,
    List<ProviderOrFamily> refresh, {
    bool postsExpense = false,
  }) async {
    final done = await guard(() async {
      await action();
      for (final provider in [
        ...refresh,
        machineReportProvider,
        if (postsExpense) expensesProvider,
      ]) {
        _ref.invalidate(provider);
      }
      return true;
    });
    return done ?? false;
  }

  Future<bool> saveMachine({
    required String name,
    required MachineKind kind,
    String? id,
    bool? isActive,
  }) => _run(
    () => _repository.saveMachine(
      name: name,
      kind: kind,
      id: id,
      isActive: isActive,
    ),
    [machinesProvider],
  );

  Future<bool> saveTask({
    required String machineId,
    required String name,
    required int everyDays,
    String? id,
    bool? isActive,
  }) => _run(
    () => _repository.saveTask(
      machineId: machineId,
      name: name,
      everyDays: everyDays,
      id: id,
      isActive: isActive,
    ),
    [maintenanceTasksProvider],
  );

  Future<bool> recordMaintenance({
    required String taskId,
    required DateTime doneOn,
    num cost = 0,
    PaymentChannel? method,
    String? note,
  }) => _run(
    () => _repository.recordMaintenance(
      taskId: taskId,
      doneOn: doneOn,
      cost: cost,
      method: method,
      note: note,
    ),
    [maintenanceTasksProvider],
    postsExpense: cost > 0,
  );

  Future<bool> reportBreakdown({
    required String machineId,
    required DateTime startedAt,
    required String cause,
  }) => _run(
    () => _repository.reportBreakdown(
      machineId: machineId,
      startedAt: startedAt,
      cause: cause,
    ),
    [breakdownsProvider],
  );

  Future<bool> endBreakdown({
    required String breakdownId,
    required DateTime endedAt,
    num repairCost = 0,
    PaymentChannel? method,
    String? note,
  }) => _run(
    () => _repository.endBreakdown(
      breakdownId: breakdownId,
      endedAt: endedAt,
      repairCost: repairCost,
      method: method,
      note: note,
    ),
    [breakdownsProvider],
    postsExpense: repairCost > 0,
  );

  Future<bool> recordDiesel({
    required String machineId,
    required DateTime date,
    required num litres,
    required num cost,
    required PaymentChannel method,
    num? runHours,
    String? note,
  }) => _run(
    () => _repository.recordDiesel(
      machineId: machineId,
      date: date,
      litres: litres,
      cost: cost,
      method: method,
      runHours: runHours,
      note: note,
    ),
    [dieselLogsProvider],
    postsExpense: true,
  );
}

final machinesActionControllerProvider =
    StateNotifierProvider.autoDispose<
      MachinesActionController,
      AsyncValue<void>
    >((ref) => MachinesActionController(ref));
