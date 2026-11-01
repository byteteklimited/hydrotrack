enum MachineKind {
  production('Production'),
  generator('Generator'),
  pump('Pump'),
  other('Other');

  const MachineKind(this.label);

  final String label;

  static MachineKind fromDb(String? value) =>
      values.where((kind) => kind.name == value).firstOrNull ?? other;
}

/// One of the organization's machines (sachet machine, bottling line,
/// generator, borehole pump…). Production runs pick from these.
class Machine {
  const Machine({
    required this.id,
    required this.name,
    required this.kind,
    required this.isActive,
  });

  final String id;
  final String name;
  final MachineKind kind;

  /// Retired machines stay in past records but aren't offered any more.
  final bool isActive;

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: MachineKind.fromDb(json['kind'] as String?),
    isActive: json['is_active'] as bool? ?? true,
  );
}

/// A repeating job on a machine, e.g. "Change filter every 30 days".
class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.machineId,
    required this.name,
    required this.everyDays,
    required this.createdOn,
    required this.isActive,
    this.lastDoneOn,
  });

  /// Shown as "due soon" this many days ahead.
  static const dueSoonDays = 3;

  final String id;
  final String machineId;
  final String name;
  final int everyDays;
  final DateTime createdOn;
  final DateTime? lastDoneOn;
  final bool isActive;

  /// Like the server's maintenance_due_on.
  DateTime get dueOn {
    final from = lastDoneOn ?? createdOn;
    return DateTime(from.year, from.month, from.day + everyDays);
  }

  /// Days until due from [today]; negative when overdue.
  int daysUntilDue(DateTime today) =>
      dueOn.difference(DateTime(today.year, today.month, today.day)).inDays;

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['created_at'] as String).toLocal();
    return MaintenanceTask(
      id: json['id'] as String,
      machineId: json['machine_id'] as String,
      name: json['name'] as String,
      everyDays: json['every_days'] as int,
      createdOn: DateTime(created.year, created.month, created.day),
      lastDoneOn: json['last_done_on'] == null
          ? null
          : DateTime.parse(json['last_done_on'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// A time a machine stopped, why, and (once fixed) what the repair cost.
class Breakdown {
  const Breakdown({
    required this.id,
    required this.machineId,
    required this.startedAt,
    required this.cause,
    required this.reportedBy,
    this.endedAt,
    this.repairCost = 0,
    this.note,
  });

  final String id;
  final String machineId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String cause;
  final num repairCost;
  final String? note;
  final String reportedBy;

  bool get isOpen => endedAt == null;

  /// How long it was (or has been, at [now]) stopped.
  Duration downtime(DateTime now) => (endedAt ?? now).difference(startedAt);

  /// [downtime] in hours, to one decimal place.
  double downtimeHours(DateTime now) =>
      (downtime(now).inMinutes / Duration.minutesPerHour * 10).round() / 10;

  factory Breakdown.fromJson(Map<String, dynamic> json) => Breakdown(
    id: json['id'] as String,
    machineId: json['machine_id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String).toLocal(),
    cause: json['cause'] as String,
    repairCost: json['repair_cost'] as num? ?? 0,
    note: json['note'] as String?,
    reportedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
  );
}

/// Diesel put into a machine (usually the generator).
class DieselLog {
  const DieselLog({
    required this.id,
    required this.machineId,
    required this.date,
    required this.litres,
    required this.cost,
    required this.recordedBy,
    this.runHours,
    this.note,
  });

  final String id;
  final String machineId;
  final DateTime date;
  final num litres;
  final num cost;
  final num? runHours;
  final String? note;
  final String recordedBy;

  factory DieselLog.fromJson(Map<String, dynamic> json) => DieselLog(
    id: json['id'] as String,
    machineId: json['machine_id'] as String,
    date: DateTime.parse(json['date'] as String),
    litres: json['litres'] as num,
    cost: json['cost'] as num,
    runHours: json['run_hours'] as num?,
    note: json['note'] as String?,
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
  );
}
