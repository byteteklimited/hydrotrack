/// Someone the factory buys raw materials from.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.balance,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;

  /// What the factory owes them.
  final num balance;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    balance: json['balance'] as num,
  );

  @override
  bool operator ==(Object other) => other is Supplier && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One line of a supplier's account: a purchase (adds to what we owe) or
/// a payment (takes off).
class SupplierLedgerEntry {
  const SupplierLedgerEntry({
    required this.id,
    required this.isPayment,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final bool isPayment;
  final num amount;
  final DateTime date;
  final String? note;

  factory SupplierLedgerEntry.fromJson(Map<String, dynamic> json) =>
      SupplierLedgerEntry(
        id: json['id'] as String,
        isPayment: json['type'] == 'payment',
        amount: json['amount'] as num,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
      );
}
