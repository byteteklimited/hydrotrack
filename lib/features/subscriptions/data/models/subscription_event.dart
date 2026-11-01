enum SubscriptionEventKind {
  payment('Payment'),
  freeDays('Free days'),
  suspended('Suspended'),
  resumed('Resumed');

  const SubscriptionEventKind(this.label);

  final String label;

  static SubscriptionEventKind fromKey(String key) => switch (key) {
    'payment' => payment,
    'free_days' => freeDays,
    'suspended' => suspended,
    _ => resumed,
  };
}

/// A payment, free days, or a suspension, as recorded by HydroTrack.
class SubscriptionEvent {
  const SubscriptionEvent({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.amount,
    this.months,
    this.days,
    this.note,
    this.endsAt,
  });

  final String id;
  final SubscriptionEventKind kind;
  final DateTime createdAt;
  final num? amount;
  final int? months;
  final int? days;
  final String? note;

  /// Where the paid (or trial) time ended up after this.
  final DateTime? endsAt;

  factory SubscriptionEvent.fromJson(Map<String, dynamic> json) =>
      SubscriptionEvent(
        id: json['id'] as String,
        kind: SubscriptionEventKind.fromKey(json['kind'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        amount: json['amount'] as num?,
        months: json['months'] as int?,
        days: json['days'] as int?,
        note: json['note'] as String?,
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.parse(json['ends_at'] as String),
      );
}
