/// How long an item's stock will last at the last 30 days' rate
/// (`stock_forecast`). Null [daysLeft] means it hasn't been used lately.
class StockForecast {
  const StockForecast({
    required this.itemId,
    required this.perDay,
    required this.daysLeft,
  });

  /// Shown as "running out" (and alerted) under this many days.
  static const warnDays = 7;

  /// How far back use is averaged.
  static const windowDays = 30;

  final String itemId;
  final num? perDay;
  final num? daysLeft;

  bool get runningOut => daysLeft != null && daysLeft! < warnDays;

  factory StockForecast.fromJson(Map<String, dynamic> json) => StockForecast(
    itemId: json['item_id'] as String,
    perDay: json['per_day'] as num?,
    daysLeft: json['days_left'] as num?,
  );

  /// The same sum as the server's stock_runout, from the device's copy:
  /// sales and production use in the last 30 days (not stock counts),
  /// averaged over at most 30 days since the item's first movement.
  static Map<String, StockForecast> compute({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> movements,
    required DateTime now,
  }) {
    final since = now.subtract(const Duration(days: windowDays));
    final used = <String, num>{};
    final first = <String, DateTime>{};
    for (final movement in movements) {
      final itemId = movement['item_id'] as String;
      final at = DateTime.parse(movement['at'] as String);
      if (at.isAfter(now)) continue;
      if (first[itemId] == null || at.isBefore(first[itemId]!)) {
        first[itemId] = at;
      }
      final quantity = movement['quantity'] as num;
      final type = movement['type'] as String;
      if ((type == 'stock_out' || type == 'production_use') &&
          quantity < 0 &&
          !at.isBefore(since)) {
        used[itemId] = (used[itemId] ?? 0) - quantity;
      }
    }
    return {
      for (final item in items)
        item['id'] as String: () {
          final id = item['id'] as String;
          final total = used[id] ?? 0;
          if (total <= 0) {
            return StockForecast(itemId: id, perDay: null, daysLeft: null);
          }
          final observed =
              now.difference(first[id]!).inMinutes / Duration.minutesPerDay;
          final days = observed.clamp(1, windowDays);
          final perDay = total / days;
          final onHand = (item['quantity_on_hand'] as num).clamp(
            0,
            double.infinity,
          );
          return StockForecast(
            itemId: id,
            perDay: perDay,
            daysLeft: onHand / perDay,
          );
        }(),
    };
  }
}
