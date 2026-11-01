/// A record made offline that a manager should check: saved although the
/// server didn't show enough stock or raw material, or it took a customer
/// over their credit limit (`sync_flags`, migration 0015).
class SyncFlag {
  const SyncFlag({
    required this.id,
    required this.kind,
    required this.details,
    required this.createdAt,
    this.saleId,
    this.productionRunId,
  });

  final String id;
  final SyncFlagKind kind;
  final String details;
  final DateTime createdAt;
  final String? saleId;
  final String? productionRunId;

  factory SyncFlag.fromJson(Map<String, dynamic> json) {
    return SyncFlag(
      id: json['id'] as String,
      kind: SyncFlagKind.fromDb(json['kind'] as String),
      details: json['details'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      saleId: json['sale_id'] as String?,
      productionRunId: json['production_run_id'] as String?,
    );
  }
}

enum SyncFlagKind {
  shortStock('short_stock', 'Sold with stock short'),
  shortRawMaterial('short_raw_material', 'Produced with raw material short'),
  overCreditLimit('over_credit_limit', 'Over credit limit'),
  cashShort('cash_short', 'Cash count short');

  const SyncFlagKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SyncFlagKind fromDb(String value) =>
      values.firstWhere((kind) => kind.dbValue == value);
}
