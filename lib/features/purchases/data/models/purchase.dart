/// Raw materials bought from a supplier: paid now, on credit, or part.
class Purchase {
  const Purchase({
    required this.id,
    required this.supplierName,
    required this.date,
    required this.total,
    required this.amountPaid,
    required this.lines,
    required this.recordedBy,
    this.note,
  });

  final String id;
  final String supplierName;
  final DateTime date;
  final num total;
  final num amountPaid;
  final List<PurchaseLine> lines;
  final String recordedBy;
  final String? note;

  num get owed => total - amountPaid;

  /// A `purchases` row with `suppliers(name)`,
  /// `purchase_lines(*, stock_items(name, unit))` and
  /// `profiles!recorded_by(full_name)` embedded.
  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
    id: json['id'] as String,
    supplierName: (json['suppliers'] as Map?)?['name'] as String? ?? 'Supplier',
    date: DateTime.parse(json['date'] as String),
    total: json['total'] as num,
    amountPaid: json['amount_paid'] as num,
    note: json['note'] as String?,
    recordedBy:
        (json['profiles'] as Map?)?['full_name'] as String? ?? 'Unknown',
    lines: [
      for (final line in json['purchase_lines'] as List? ?? const [])
        PurchaseLine.fromJson(line as Map<String, dynamic>),
    ],
  );
}

class PurchaseLine {
  const PurchaseLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.unitCost,
  });

  final String itemId;
  final String itemName;
  final String unit;
  final int quantity;
  final num unitCost;

  num get lineTotal => quantity * unitCost;

  factory PurchaseLine.fromJson(Map<String, dynamic> json) {
    final item = json['stock_items'] as Map?;
    return PurchaseLine(
      itemId: json['item_id'] as String,
      itemName: item?['name'] as String? ?? 'Item',
      unit: item?['unit'] as String? ?? '',
      quantity: json['quantity'] as int,
      unitCost: json['unit_cost'] as num,
    );
  }

  /// What record_purchase takes for this line.
  Map<String, dynamic> toPayload() => {
    'item_id': itemId,
    'quantity': quantity,
    'unit_cost': unitCost,
  };
}
