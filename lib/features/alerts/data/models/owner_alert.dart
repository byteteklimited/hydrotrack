/// Something the owner should know: the daily summary or low stock
/// (migration 0022).
class OwnerAlert {
  const OwnerAlert({
    required this.id,
    required this.isLowStock,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final bool isLowStock;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  factory OwnerAlert.fromJson(Map<String, dynamic> json) => OwnerAlert(
    id: json['id'] as String,
    isLowStock: json['kind'] == 'low_stock',
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    isRead: json['read_at'] != null,
  );
}
