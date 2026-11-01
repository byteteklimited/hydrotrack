import 'sale_line.dart';

/// Who bought: a walk-in customer, or a known distributor.
enum CustomerType { walkIn, distributor }

extension CustomerTypeLabel on CustomerType {
  String get label => switch (this) {
    CustomerType.walkIn => 'Walk-in',
    CustomerType.distributor => 'Distributor',
  };

  /// The exact string stored in Postgres (`sales_customer_type` enum).
  String get dbValue => switch (this) {
    CustomerType.walkIn => 'walk_in',
    CustomerType.distributor => 'distributor',
  };
}

/// `sales.customer_type` is a Postgres enum with a snake_case value for
/// walk-in.
CustomerType customerTypeFromDb(String value) => switch (value) {
  'walk_in' => CustomerType.walkIn,
  'distributor' => CustomerType.distributor,
  _ => throw ArgumentError('Unknown customer type: $value'),
};

/// How the sale was settled. [part] means some was paid now, the rest owed;
/// [credit] means nothing was paid now, the full total is owed.
enum PaymentMethod { cash, transfer, part, credit }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.transfer => 'Transfer',
    PaymentMethod.part => 'Part payment',
    PaymentMethod.credit => 'Credit',
  };
}

/// What actually matters once a sale is recorded — not *how* it was
/// paid (cash vs transfer look identical to a customer's balance) but
/// *whether* it's settled. Drives the sales list's status badge instead
/// of [PaymentMethod] directly, so "Cash" and "Transfer" — which both
/// mean fully paid — read the same way.
enum SalePaymentStatus { paid, partPaid, onCredit }

extension SalePaymentStatusLabel on SalePaymentStatus {
  String get label => switch (this) {
    SalePaymentStatus.paid => 'Paid',
    SalePaymentStatus.partPaid => 'Part-paid',
    SalePaymentStatus.onCredit => 'On credit',
  };
}

/// A completed sale: one or more product lines, how it was paid, and what
/// (if anything) is still owed.
class Sale {
  const Sale({
    required this.id,
    required this.dateTime,
    required this.customerType,
    required this.lines,
    required this.total,
    required this.amountPaid,
    required this.paymentMethod,
    required this.balance,
    required this.recordedBy,
    this.customerName,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.batchNumbers = const [],
  });

  final String id;
  final DateTime dateTime;
  final CustomerType customerType;
  final String? customerName;
  final List<SaleLine> lines;
  final num total;
  final num amountPaid;
  final PaymentMethod paymentMethod;
  final num balance;
  final String recordedBy;

  /// Null unless this sale has been voided — never hard-deleted, so the
  /// record stays visible in the list/audit trail, but every revenue/
  /// cash/debt total must exclude it (see [isVoided]).
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;

  /// Production batches its bags came from (oldest first), for tracing
  /// a bad batch; printed on receipts (migration 0025).
  final List<String> batchNumbers;

  bool get isVoided => voidedAt != null;

  int get totalBags => lines.fold(0, (sum, line) => sum + line.quantity);

  /// [balance] is the source of truth, not [paymentMethod] — a `part`
  /// payment that happens to cover the full total is paid, not
  /// part-paid, and this reads correctly either way.
  SalePaymentStatus get paymentStatus {
    if (balance <= 0) return SalePaymentStatus.paid;
    if (amountPaid > 0) return SalePaymentStatus.partPaid;
    return SalePaymentStatus.onCredit;
  }

  /// `sale_lines` and `profiles` are joined resources when this comes
  /// from Supabase — nested under the referenced table's name, not
  /// under a flat `lines`/`recorded_by` string.
  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    dateTime: DateTime.parse(json['date_time'] as String),
    customerType: customerTypeFromDb(json['customer_type'] as String),
    customerName: json['customer_name'] as String?,
    lines: (json['sale_lines'] as List<dynamic>)
        .map((e) => SaleLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    total: json['total'] as num,
    amountPaid: json['amount_paid'] as num,
    paymentMethod: PaymentMethod.values.byName(
      json['payment_method'] as String,
    ),
    balance: json['balance'] as num,
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
    voidedAt: json['voided_at'] == null
        ? null
        : DateTime.parse(json['voided_at'] as String),
    voidedBy:
        (json['voided_by_profile'] as Map<String, dynamic>?)?['full_name']
            as String?,
    voidReason: json['void_reason'] as String?,
    batchNumbers: [
      for (final number in json['batch_numbers'] as List? ?? const [])
        number as String,
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date_time': dateTime.toIso8601String(),
    'customer_type': customerType.dbValue,
    'customer_name': customerName,
    'lines': lines.map((line) => line.toJson()).toList(),
    'total': total,
    'amount_paid': amountPaid,
    'payment_method': paymentMethod.name,
    'balance': balance,
    'recorded_by': recordedBy,
    'voided_at': voidedAt?.toIso8601String(),
    'void_reason': voidReason,
  };
}
