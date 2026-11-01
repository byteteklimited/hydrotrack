import 'package:flutter/material.dart';

/// What kind of event moved stock. [adjustment] is a count correction and
/// can go either direction; the others have a fixed sign in [quantity].
enum MovementType {
  stockIn,
  stockOut,
  adjustment,
  productionUse,
  transferOut,
  transferIn,
}

extension MovementTypeMeta on MovementType {
  String get label => switch (this) {
    MovementType.stockIn => 'Stock in',
    MovementType.stockOut => 'Stock out',
    MovementType.adjustment => 'Adjustment',
    MovementType.productionUse => 'Used in production',
    MovementType.transferOut => 'Sent to another location',
    MovementType.transferIn => 'Received from another location',
  };

  IconData get icon => switch (this) {
    MovementType.stockIn => Icons.add_circle_outline,
    MovementType.stockOut => Icons.remove_circle_outline,
    MovementType.adjustment => Icons.tune,
    MovementType.productionUse => Icons.factory_outlined,
    MovementType.transferOut => Icons.north_east,
    MovementType.transferIn => Icons.south_west,
  };
}

/// One entry in an item's ledger. [quantity] is signed — positive when
/// stock increased, negative when it decreased — so [adjustment] can
/// represent a correction in either direction.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.byWhom,
    required this.at,
    this.note,
    this.unitCost,
  });

  final String id;
  final String itemId;
  final MovementType type;
  final int quantity;
  final String? note;
  final String byWhom;
  final DateTime at;

  /// Cost per unit at the time (migration 0021).
  final num? unitCost;

  /// `by_whom` is a Postgres FK to `profiles`, so a row fetched from
  /// Supabase carries the joined `profiles.full_name` here instead of the
  /// raw id.
  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: json['id'] as String,
    itemId: json['item_id'] as String,
    type: _typeFromDb(json['type'] as String),
    quantity: json['quantity'] as int,
    note: json['note'] as String?,
    byWhom:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
    at: DateTime.parse(json['at'] as String),
    unitCost: json['unit_cost'] as num?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'type': _typeToDb(type),
    'quantity': quantity,
    'note': note,
    'by_whom': byWhom,
    'at': at.toIso8601String(),
  };
}

/// `stock_movements.type` is a Postgres enum with snake_case values.
MovementType _typeFromDb(String value) => switch (value) {
  'stock_in' => MovementType.stockIn,
  'stock_out' => MovementType.stockOut,
  'adjustment' => MovementType.adjustment,
  'production_use' => MovementType.productionUse,
  'transfer_out' => MovementType.transferOut,
  'transfer_in' => MovementType.transferIn,
  _ => throw ArgumentError('Unknown movement type: $value'),
};

String _typeToDb(MovementType type) => switch (type) {
  MovementType.stockIn => 'stock_in',
  MovementType.stockOut => 'stock_out',
  MovementType.adjustment => 'adjustment',
  MovementType.productionUse => 'production_use',
  MovementType.transferOut => 'transfer_out',
  MovementType.transferIn => 'transfer_in',
};
