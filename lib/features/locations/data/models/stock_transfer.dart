/// Stock sent from one location to another (`location_transfers`).
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.incoming,
    required this.received,
    required this.sentAt,
    required this.items,
    this.receivedAt,
    this.sentBy,
    this.note,
  });

  final String id;
  final String fromLocation;
  final String toLocation;

  /// Coming to the current location (otherwise going from it).
  final bool incoming;
  final bool received;
  final DateTime sentAt;
  final DateTime? receivedAt;
  final String? sentBy;
  final String? note;
  final List<TransferItem> items;

  /// Waiting for the current location to receive it.
  bool get toReceive => incoming && !received;

  factory StockTransfer.fromJson(Map<String, dynamic> json) => StockTransfer(
    id: json['id'] as String,
    fromLocation: json['from_location'] as String,
    toLocation: json['to_location'] as String,
    incoming: json['incoming'] as bool,
    received: json['status'] == 'received',
    sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
    receivedAt: json['received_at'] == null
        ? null
        : DateTime.parse(json['received_at'] as String).toLocal(),
    sentBy: json['sent_by'] as String?,
    note: json['note'] as String?,
    items: [
      for (final item in json['items'] as List? ?? const [])
        TransferItem.fromJson(item as Map<String, dynamic>),
    ],
  );
}

class TransferItem {
  const TransferItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });

  final String name;
  final String unit;
  final int quantity;

  factory TransferItem.fromJson(Map<String, dynamic> json) => TransferItem(
    name: json['name'] as String,
    unit: json['unit'] as String,
    quantity: json['quantity'] as int,
  );
}
