/// How urgent a batch's expiry is — drives the same red/amber/neutral
/// read as [StockStatus], never decoration.
enum BatchExpiryStatus { none, expiringSoon, expired }

/// A batch stays "expiring soon" inside this window before its date.
/// Factory judgment call: long enough to actually act on (reorder,
/// prioritize dispatching it), short enough not to flag everything.
const expiryWarningWindow = Duration(days: 30);

/// One delivery (raw material) or one production run's output (finished
/// goods) — the unit stock is actually drawn from, oldest first.
/// [quantityReceived] never changes after creation except when a
/// production run that created this batch is later edited; a batch is
/// otherwise immutable history, only [quantityRemaining] moves.
class StockBatch {
  const StockBatch({
    required this.id,
    required this.itemId,
    required this.receivedAt,
    required this.quantityReceived,
    required this.quantityRemaining,
    this.expiryDate,
    this.productionRunId,
  });

  final String id;
  final String itemId;
  final DateTime receivedAt;
  final int quantityReceived;
  final int quantityRemaining;
  final DateTime? expiryDate;

  /// Set only for a batch a production run's own output created —
  /// null for every batch that came from a delivery or a load-out
  /// return.
  final String? productionRunId;

  bool get isDepleted => quantityRemaining <= 0;

  /// No [expiryDate] means this batch was never meant to be tracked for
  /// expiry (e.g. bottle preforms) — always [BatchExpiryStatus.none].
  BatchExpiryStatus get expiryStatus {
    final expiry = expiryDate;
    if (expiry == null) return BatchExpiryStatus.none;
    final today = DateTime.now();
    if (expiry.isBefore(today)) return BatchExpiryStatus.expired;
    if (expiry.isBefore(today.add(expiryWarningWindow))) {
      return BatchExpiryStatus.expiringSoon;
    }
    return BatchExpiryStatus.none;
  }

  factory StockBatch.fromJson(Map<String, dynamic> json) => StockBatch(
    id: json['id'] as String,
    itemId: json['item_id'] as String,
    receivedAt: DateTime.parse(json['received_at'] as String),
    quantityReceived: json['quantity_received'] as int,
    quantityRemaining: json['quantity_remaining'] as int,
    expiryDate: json['expiry_date'] == null
        ? null
        : DateTime.parse(json['expiry_date'] as String),
    productionRunId: json['production_run_id'] as String?,
  );
}
