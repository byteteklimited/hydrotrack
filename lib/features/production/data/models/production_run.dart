import '../../../products/data/models/product.dart';

export '../../../products/data/models/product.dart';

/// A production shift. This factory runs two: Morning and Afternoon.
enum ProductionShift { morning, afternoon }

extension ProductionShiftLabel on ProductionShift {
  String get label => switch (this) {
    ProductionShift.morning => 'Morning',
    ProductionShift.afternoon => 'Afternoon',
  };
}

/// The factory's production machines.
class ProductionMachines {
  ProductionMachines._();

  static const all = ['Machine 1', 'Machine 2'];
}

/// One production run: a shift on a machine, what was made, how much, and
/// how much was wasted. [recordedBy]/[recordedAt] make this the visible
/// audit trail for production entries.
class ProductionRun {
  const ProductionRun({
    required this.id,
    required this.date,
    required this.shift,
    required this.machine,
    required this.operatorName,
    required this.product,
    required this.quantityProduced,
    required this.wastage,
    required this.recordedBy,
    required this.recordedAt,
  });

  final String id;
  final DateTime date;
  final ProductionShift shift;
  final String machine;
  final String operatorName;
  final Product product;
  final int quantityProduced;
  final int wastage;
  final String recordedBy;
  final DateTime recordedAt;

  /// Wastage as a percentage of everything this run processed (good +
  /// wasted) — the same formula the dashboard's daily total uses, so one
  /// run and the day it belongs to can never disagree about the number.
  double get wastagePercent {
    final total = quantityProduced + wastage;
    return total == 0 ? 0 : (wastage / total) * 100;
  }

  /// `recorded_by` is a Postgres FK to `profiles`, so a row fetched from
  /// Supabase carries the joined `profiles.full_name` here instead of the
  /// raw id — the audit trail always shows a name, never a uuid.
  factory ProductionRun.fromJson(Map<String, dynamic> json) => ProductionRun(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    shift: ProductionShift.values.byName(json['shift'] as String),
    machine: json['machine'] as String,
    operatorName: json['operator_name'] as String,
    product: Product.fromRecord(json),
    quantityProduced: json['quantity_produced'] as int,
    wastage: json['wastage'] as int,
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'shift': shift.name,
    'machine': machine,
    'operator_name': operatorName,
    ...product.toRecordJson(),
    'quantity_produced': quantityProduced,
    'wastage': wastage,
    'recorded_by': recordedBy,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
