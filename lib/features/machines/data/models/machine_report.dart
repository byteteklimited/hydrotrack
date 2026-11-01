/// A period's figures per machine and diesel per bag (`machine_report`).
class MachineReport {
  const MachineReport({
    required this.machines,
    required this.bags,
    required this.litres,
    required this.dieselCost,
    this.litresPer100Bags,
    this.dieselCostPerBag,
  });

  final List<MachineReportRow> machines;
  final int bags;
  final num litres;
  final num dieselCost;

  /// Null when no bags were made.
  final num? litresPer100Bags;
  final num? dieselCostPerBag;

  num get downtimeHours =>
      machines.fold<num>(0, (sum, row) => sum + row.downtimeHours);

  MachineReportRow? forMachine(String id) =>
      machines.where((row) => row.machineId == id).firstOrNull;

  factory MachineReport.fromJson(Map<String, dynamic> json) => MachineReport(
    machines: [
      for (final row in json['machines'] as List? ?? const [])
        MachineReportRow.fromJson(row as Map<String, dynamic>),
    ],
    bags: (json['bags'] as num).toInt(),
    litres: json['litres'] as num,
    dieselCost: json['diesel_cost'] as num,
    litresPer100Bags: json['litres_per_100_bags'] as num?,
    dieselCostPerBag: json['diesel_cost_per_bag'] as num?,
  );
}

class MachineReportRow {
  const MachineReportRow({
    required this.machineId,
    required this.bags,
    required this.downtimeHours,
    required this.breakdowns,
    required this.repairCost,
    required this.maintenanceCost,
    required this.litres,
  });

  final String machineId;
  final int bags;
  final num downtimeHours;
  final int breakdowns;
  final num repairCost;
  final num maintenanceCost;
  final num litres;

  factory MachineReportRow.fromJson(Map<String, dynamic> json) =>
      MachineReportRow(
        machineId: json['machine_id'] as String,
        bags: (json['bags'] as num).toInt(),
        downtimeHours: json['downtime_hours'] as num,
        breakdowns: (json['breakdowns'] as num).toInt(),
        repairCost: json['repair_cost'] as num,
        maintenanceCost: json['maintenance_cost'] as num,
        litres: json['litres'] as num,
      );
}
