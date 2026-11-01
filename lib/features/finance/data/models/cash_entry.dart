import '../../../../core/constants/payment_channel.dart';

export '../../../../core/constants/payment_channel.dart';

/// Which way money moved.
enum CashDirection { moneyIn, moneyOut }

extension CashDirectionLabel on CashDirection {
  String get label => switch (this) {
    CashDirection.moneyIn => 'Money in',
    CashDirection.moneyOut => 'Money out',
  };

  /// The exact string stored in Postgres (`cash_direction` enum).
  String get dbValue => switch (this) {
    CashDirection.moneyIn => 'money_in',
    CashDirection.moneyOut => 'money_out',
  };
}

/// `cash_entries.direction` is a Postgres enum with snake_case values.
CashDirection directionFromDb(String value) => switch (value) {
  'money_in' => CashDirection.moneyIn,
  'money_out' => CashDirection.moneyOut,
  _ => throw ArgumentError('Unknown cash direction: $value'),
};

/// Where a cash movement came from or went to. [sales] and [debtPayment]
/// are populated automatically from those features in Phase 3; the rest
/// are recorded directly here.
enum CashSource { sales, debtPayment, expense, wages, ownerDrawing, other }

extension CashSourceLabel on CashSource {
  String get label => switch (this) {
    CashSource.sales => 'Sales',
    CashSource.debtPayment => 'Debt payment',
    CashSource.expense => 'Expense',
    CashSource.wages => 'Wages',
    CashSource.ownerDrawing => 'Owner drawing',
    CashSource.other => 'Other',
  };

  /// The exact string stored in Postgres (`cash_source` enum).
  String get dbValue => switch (this) {
    CashSource.sales => 'sales',
    CashSource.debtPayment => 'debt_payment',
    CashSource.expense => 'expense',
    CashSource.wages => 'wages',
    CashSource.ownerDrawing => 'owner_drawing',
    CashSource.other => 'other',
  };
}

/// `cash_entries.source` is a Postgres enum with snake_case values.
CashSource sourceFromDb(String value) => switch (value) {
  'sales' => CashSource.sales,
  'debt_payment' => CashSource.debtPayment,
  'expense' => CashSource.expense,
  'wages' => CashSource.wages,
  'owner_drawing' => CashSource.ownerDrawing,
  'other' => CashSource.other,
  _ => throw ArgumentError('Unknown cash source: $value'),
};

/// One line of money in or out — the full picture of cash movement,
/// whether it originated in Sales, Debts, or was recorded directly here.
class CashEntry {
  const CashEntry({
    required this.id,
    required this.dateTime,
    required this.direction,
    required this.source,
    required this.amount,
    required this.method,
    required this.recordedBy,
    this.note,
  });

  final String id;
  final DateTime dateTime;
  final CashDirection direction;
  final CashSource source;
  final num amount;
  final PaymentChannel method;
  final String? note;
  final String recordedBy;

  /// Positive when money came in, negative when it went out — ready for
  /// display and for summing into running totals.
  num get signedAmount => direction == CashDirection.moneyIn ? amount : -amount;

  /// `recorded_by` is a Postgres FK to `profiles`, so a row fetched from
  /// Supabase carries the joined `profiles.full_name` here instead of the
  /// raw id.
  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
    id: json['id'] as String,
    dateTime: DateTime.parse(json['date_time'] as String),
    direction: directionFromDb(json['direction'] as String),
    source: sourceFromDb(json['source'] as String),
    amount: json['amount'] as num,
    method: PaymentChannel.values.byName(json['method'] as String),
    note: json['note'] as String?,
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date_time': dateTime.toIso8601String(),
    'direction': direction.dbValue,
    'source': source.dbValue,
    'amount': amount,
    'method': method.name,
    'note': note,
    'recorded_by': recordedBy,
  };
}
