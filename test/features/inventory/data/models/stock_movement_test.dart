import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_movement.dart';

void main() {
  group('StockMovement JSON', () {
    test('fromJson reads the joined profiles.full_name as byWhom', () {
      final movement = StockMovement.fromJson({
        'id': 'sm1',
        'item_id': 'si1',
        'type': 'stock_out',
        'quantity': -50,
        'note': '50 bags dispatched on load-out',
        'profiles': {'full_name': 'Amina Yusuf'},
        'at': '2026-03-05T07:00:00.000Z',
      });
      expect(movement.byWhom, 'Amina Yusuf');
      expect(movement.type, MovementType.stockOut);
      expect(movement.quantity, -50);
    });

    test('fromJson falls back to "Unknown" when profiles is missing', () {
      final movement = StockMovement.fromJson({
        'id': 'sm1',
        'item_id': 'si1',
        'type': 'adjustment',
        'quantity': 5,
        'note': null,
        'profiles': null,
        'at': '2026-03-05T07:00:00.000Z',
      });
      expect(movement.byWhom, 'Unknown');
    });

    test('toJson preserves the sign of quantity', () {
      final movement = StockMovement(
        id: 'sm1',
        itemId: 'si1',
        type: MovementType.stockIn,
        quantity: 15,
        byWhom: 'Amina Yusuf',
        at: DateTime(2026, 3, 5),
      );
      expect(movement.toJson()['quantity'], 15);
      expect(movement.toJson()['type'], 'stock_in');
    });
  });
}
