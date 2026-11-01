import '../../../../core/constants/debts_thresholds.dart';

/// A distributor or credit customer who can carry a balance.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.area,
    required this.creditLimit,
    required this.balance,
    this.lastPaymentDate,
  });

  final String id;
  final String name;
  final String phone;
  final String area;
  final num creditLimit;
  final num balance;
  final DateTime? lastPaymentDate;

  bool get isOverCreditLimit => balance >= creditLimit;

  /// A negative balance means this customer has paid more than they
  /// currently owe — an advance or an overpayment. That's a liability
  /// for the business (water or a refund is owed to them), not "nothing
  /// outstanding" the way an exact-zero balance is — so it gets its own
  /// read instead of being folded into "settled".
  bool get isInCredit => balance < 0;

  /// True once this customer has gone [DebtsThresholds.overdueDays] or
  /// more without a payment while still owing money.
  bool get isOverdue {
    if (balance <= 0) return false;
    if (lastPaymentDate == null) return true;
    final daysSincePayment = DateTime.now().difference(lastPaymentDate!).inDays;
    return daysSincePayment >= DebtsThresholds.overdueDays;
  }

  Customer copyWith({
    num? balance,
    num? creditLimit,
    DateTime? lastPaymentDate,
  }) {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      area: area,
      creditLimit: creditLimit ?? this.creditLimit,
      balance: balance ?? this.balance,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    area: json['area'] as String,
    creditLimit: json['credit_limit'] as num,
    balance: json['balance'] as num,
    lastPaymentDate: json['last_payment_date'] == null
        ? null
        : DateTime.parse(json['last_payment_date'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'area': area,
    'credit_limit': creditLimit,
    'balance': balance,
    'last_payment_date': lastPaymentDate?.toIso8601String(),
  };
}
