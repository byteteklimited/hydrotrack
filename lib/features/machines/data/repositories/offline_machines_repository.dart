import '../../../../core/constants/payment_channel.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/machine.dart';
import '../models/machine_report.dart';
import 'machines_repository.dart';

typedef _Payloads = SupabaseMachinesRepository;

/// On a device set up for offline use: diesel, maintenance done and
/// breakdowns are saved on the device first, then sent; setting up
/// machines and tasks, and the report, need internet.
class OfflineMachinesRepository implements MachinesRepository {
  OfflineMachinesRepository(this._remote, this._offline);

  final MachinesRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Machine>> fetchMachines() => _offline.read(
    remote: _remote.fetchMachines,
    local: (snapshot) =>
        snapshot.rows('machines').map(Machine.fromJson).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<void> saveMachine({
    required String name,
    required MachineKind kind,
    String? id,
    bool? isActive,
  }) => _offline.online(
    () =>
        _remote.saveMachine(name: name, kind: kind, id: id, isActive: isActive),
  );

  @override
  Future<List<MaintenanceTask>> fetchTasks() => _offline.read(
    remote: _remote.fetchTasks,
    local: (snapshot) => snapshot
        .rows('maintenance_tasks')
        .map(MaintenanceTask.fromJson)
        .toList(),
  );

  @override
  Future<void> saveTask({
    required String machineId,
    required String name,
    required int everyDays,
    String? id,
    bool? isActive,
  }) => _offline.online(
    () => _remote.saveTask(
      machineId: machineId,
      name: name,
      everyDays: everyDays,
      id: id,
      isActive: isActive,
    ),
  );

  @override
  Future<void> recordMaintenance({
    required String taskId,
    required DateTime doneOn,
    num cost = 0,
    PaymentChannel? method,
    String? note,
  }) => _offline.record(
    OperationType.maintenanceDone,
    _Payloads.maintenancePayload(
      taskId: taskId,
      doneOn: doneOn,
      cost: cost,
      method: method,
      note: note,
    ),
  );

  @override
  Future<List<Breakdown>> fetchBreakdowns({required DateTime since}) =>
      _offline.read(
        remote: () => _remote.fetchBreakdowns(since: since),
        local: (snapshot) =>
            snapshot
                .rows('breakdowns')
                .map(Breakdown.fromJson)
                .where((b) => b.isOpen || !b.startedAt.isBefore(since))
                .toList()
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      );

  @override
  Future<void> reportBreakdown({
    required String machineId,
    required DateTime startedAt,
    required String cause,
  }) => _offline.record(
    OperationType.breakdown,
    _Payloads.breakdownPayload(
      // The device names it, so it can be marked fixed before it syncs.
      id: _offline.newId(),
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
  }) => _offline.record(
    OperationType.breakdownEnd,
    _Payloads.breakdownEndPayload(
      breakdownId: breakdownId,
      endedAt: endedAt,
      repairCost: repairCost,
      method: method,
      note: note,
    ),
  );

  @override
  Future<List<DieselLog>> fetchDieselLogs({required DateTime since}) =>
      _offline.read(
        remote: () => _remote.fetchDieselLogs(since: since),
        local: (snapshot) =>
            snapshot
                .rows('diesel_logs')
                .map(DieselLog.fromJson)
                .where((log) => !log.date.isBefore(since))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
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
  }) => _offline.record(
    OperationType.diesel,
    _Payloads.dieselPayload(
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
  }) => _offline.online(() => _remote.fetchReport(from: from, to: to));
}
