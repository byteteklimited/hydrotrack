import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_forecast.dart';
import 'package:hydrotrack/features/inventory/view/widgets/inventory_item_tile.dart';

final _now = DateTime.utc(2026, 11, 30, 12);

Map<String, dynamic> _move(
  String item,
  String type,
  int quantity,
  int daysAgo,
) => {
  'item_id': item,
  'type': type,
  'quantity': quantity,
  'at': _now.subtract(Duration(days: daysAgo)).toIso8601String(),
};

void main() {
  test('offline forecasts use the same sums as the server', () {
    final forecasts = StockForecast.compute(
      items: [
        {'id': 'nylon', 'quantity_on_hand': 100},
        {'id': 'preforms', 'quantity_on_hand': 40},
        {'id': 'caps', 'quantity_on_hand': 50},
      ],
      movements: [
        _move('nylon', 'stock_in', 160, 40),
        _move('nylon', 'production_use', -30, 20),
        _move('nylon', 'production_use', -30, 5),
        _move('nylon', 'production_use', -50, 35),
        _move('nylon', 'adjustment', -5, 3),
        _move('preforms', 'stock_in', 60, 10),
        _move('preforms', 'stock_out', -20, 2),
      ],
      now: _now,
    );
    expect(forecasts['nylon']!.perDay, 2, reason: 'last 30 days, no counts');
    expect(forecasts['nylon']!.daysLeft, 50);
    expect(forecasts['preforms']!.perDay, 2, reason: 'over its 10 days');
    expect(forecasts['caps']!.daysLeft, isNull, reason: 'not used lately');
  });

  test('days left read simply', () {
    StockForecast forecast(num? days) =>
        StockForecast(itemId: 'x', perDay: 1, daysLeft: days);
    expect(InventoryItemTile.daysLeftText(forecast(5.6)), 'about 5 days left');
    expect(InventoryItemTile.daysLeftText(forecast(1.2)), 'about 1 day left');
    expect(InventoryItemTile.daysLeftText(forecast(0.4)), 'runs out today');
    expect(InventoryItemTile.daysLeftText(forecast(null)), isNull);
    expect(forecast(6.9).runningOut, isTrue);
    expect(forecast(7).runningOut, isFalse);
  });
}
