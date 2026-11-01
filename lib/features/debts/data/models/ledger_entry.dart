export '../../../../core/constants/payment_channel.dart';

/// What a ledger entry represents and how it moves a customer's
/// balance: a sale (adds), a payment or a voided sale's credit being
/// removed or a write-off (each subtracts), or an opening balance —
/// the one type that can go either way, since the customer may already
/// have owed money or already had credit before this system existed.
enum LedgerEntryType { sale, payment, voided, openingBalance, writeOff }

/// `ledger_entries.type` is a Postgres enum with snake_case values for
/// the two multi-word entries — `.byName`/`.name` alone can't bridge
/// `openingBalance` to `opening_balance`.
LedgerEntryType ledgerEntryTypeFromDb(String value) => switch (value) {
  'sale' => LedgerEntryType.sale,
  'payment' => LedgerEntryType.payment,
  'voided' => LedgerEntryType.voided,
  'opening_balance' => LedgerEntryType.openingBalance,
  'write_off' => LedgerEntryType.writeOff,
  _ => throw ArgumentError('Unknown ledger entry type: $value'),
};

extension LedgerEntryTypeX on LedgerEntryType {
  String get dbValue => switch (this) {
    LedgerEntryType.sale => 'sale',
    LedgerEntryType.payment => 'payment',
    LedgerEntryType.voided => 'voided',
    LedgerEntryType.openingBalance => 'opening_balance',
    LedgerEntryType.writeOff => 'write_off',
  };

  /// How [LedgerEntry.amount] moves the running balance. Every type but
  /// opening balance has a fixed direction and an always-positive
  /// magnitude (sale always adds, payment/voided/write-off always
  /// subtract); an opening balance genuinely can go either way, so its
  /// own amount is signed instead of fixed-direction — see
  /// `add_opening_balance`'s own migration comment.
  num balanceDelta(num amount) => switch (this) {
    LedgerEntryType.sale => amount,
    LedgerEntryType.payment ||
    LedgerEntryType.voided ||
    LedgerEntryType.writeOff => -amount,
    LedgerEntryType.openingBalance => amount,
  };

  /// Shown when the entry has no [LedgerEntry.note] of its own.
  String get defaultLabel => switch (this) {
    LedgerEntryType.sale => 'Sale',
    LedgerEntryType.payment => 'Payment',
    LedgerEntryType.voided => 'Voided sale',
    LedgerEntryType.openingBalance => 'Opening balance',
    LedgerEntryType.writeOff => 'Write-off',
  };
}

/// One line in a customer's ledger: a sale (adds to balance) or a payment
/// (subtracts from it).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final String customerId;
  final LedgerEntryType type;
  final num amount;
  final DateTime date;
  final String? note;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as String,
    customerId: json['customer_id'] as String,
    type: ledgerEntryTypeFromDb(json['type'] as String),
    amount: json['amount'] as num,
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'type': type.dbValue,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };
}

/// Folds [entries] (oldest first) into a running balance per entry, most
/// recent first — what [CustomerDetailScreen] shows as the ledger, and
/// the one place this formula lives so a customer's statement and their
/// [Customer.balance] can never silently disagree. The last tuple's
/// balance (i.e. the first after reversing) is the customer's current
/// balance, by construction — same reconstruction the Reports repository
/// does to answer "what was the balance as of some earlier date".
List<(LedgerEntry, num)> ledgerWithRunningBalances(List<LedgerEntry> entries) {
  num running = 0;
  final result = <(LedgerEntry, num)>[];
  for (final entry in entries) {
    running += entry.type.balanceDelta(entry.amount);
    result.add((entry, running));
  }
  return result.reversed.toList();
}
