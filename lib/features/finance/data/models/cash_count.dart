/// What a cashier should be holding: cash in they recorded minus cash out
/// they paid, since [since] (their last count today, or the start of the
/// day).
class ExpectedCash {
  const ExpectedCash({
    required this.since,
    required this.cashIn,
    required this.cashOut,
  });

  final DateTime since;
  final num cashIn;
  final num cashOut;

  num get expected => cashIn - cashOut;

  factory ExpectedCash.fromJson(Map<String, dynamic> json) => ExpectedCash(
    since: DateTime.parse(json['since'] as String),
    cashIn: json['cash_in'] as num,
    cashOut: json['cash_out'] as num,
  );
}

/// One end-of-shift cash count.
class CashCount {
  const CashCount({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.countedAt,
    required this.expected,
    required this.counted,
    this.note,
    this.confirmedAt,
    this.confirmedBy,
  });

  final String id;
  final String cashierId;
  final String cashierName;
  final DateTime countedAt;
  final num expected;
  final num counted;
  final String? note;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  /// Positive: over. Negative: short.
  num get difference => counted - expected;
  bool get isShort => difference < 0;
  bool get isConfirmed => confirmedAt != null;

  /// A `cash_counts` row with `cashier:profiles(...)` and
  /// `confirmer:profiles(...)` embedded.
  factory CashCount.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    return CashCount(
      id: json['id'] as String,
      cashierId: json['cashier_id'] as String,
      cashierName:
          (json['cashier'] as Map?)?['full_name'] as String? ?? 'Unknown',
      countedAt: DateTime.parse(json['counted_at'] as String),
      expected: json['expected'] as num,
      counted: json['counted'] as num,
      note: json['note'] as String?,
      confirmedAt: parse(json['confirmed_at']),
      confirmedBy: (json['confirmer'] as Map?)?['full_name'] as String?,
    );
  }
}
