import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_item.dart';

import '../../../../helpers/test_products.dart';

StockItem _buildItem({int quantityOnHand = 50, int reorderLevel = 20}) {
  return StockItem(
    id: 'si1',
    name: 'Nylon rolls',
    category: StockCategory.rawMaterial,
    unit: 'rolls',
    quantityOnHand: quantityOnHand,
    reorderLevel: reorderLevel,
  );
}

void main() {
  group('StockItem JSON', () {
    test('round-trips through fromJson(toJson(x))', () {
      final item = _buildItem();
      final roundTripped = StockItem.fromJson(item.toJson());
      expect(roundTripped.id, item.id);
      expect(roundTripped.name, item.name);
      expect(roundTripped.category, item.category);
      expect(roundTripped.unit, item.unit);
      expect(roundTripped.quantityOnHand, item.quantityOnHand);
      expect(roundTripped.reorderLevel, item.reorderLevel);
    });

    test('fromJson maps finished_goods correctly', () {
      final item = StockItem.fromJson({
        'id': 'si2',
        'name': 'Sachet bags (finished)',
        'category': 'finished_goods',
        'unit': 'bags',
        'quantity_on_hand': 1000,
        'reorder_level': 200,
      });
      expect(item.category, StockCategory.finishedGoods);
      expect(item.product, isNull);
    });

    test('round-trips a linked product', () {
      final item = StockItem(
        id: 'si2',
        name: 'Sachet bags (finished)',
        category: StockCategory.finishedGoods,
        unit: 'bags',
        quantityOnHand: 1000,
        reorderLevel: 200,
        product: sachet50cl,
      );
      final roundTripped = StockItem.fromJson(item.toJson());
      expect(roundTripped.product, sachet50cl);
    });
  });

  group('isLowStock', () {
    test('true once quantity drops to the reorder level', () {
      final item = _buildItem(quantityOnHand: 20, reorderLevel: 20);
      expect(item.isLowStock, isTrue);
    });

    test('false while above the reorder level', () {
      final item = _buildItem(quantityOnHand: 50, reorderLevel: 20);
      expect(item.isLowStock, isFalse);
    });
  });

  group('status', () {
    test('is outOfStock at exactly zero, regardless of reorder level', () {
      final item = _buildItem(quantityOnHand: 0, reorderLevel: 20);
      expect(item.status, StockStatus.outOfStock);
    });

    test('is runningLow above zero but at/below the reorder level', () {
      final item = _buildItem(quantityOnHand: 20, reorderLevel: 20);
      expect(item.status, StockStatus.runningLow);
    });

    test('is healthy once above the reorder level', () {
      final item = _buildItem(quantityOnHand: 21, reorderLevel: 20);
      expect(item.status, StockStatus.healthy);
    });
  });

  group('copyWith', () {
    test('updates quantityOnHand without touching other fields', () {
      final item = _buildItem(quantityOnHand: 50);
      final updated = item.copyWith(quantityOnHand: 30);
      expect(updated.quantityOnHand, 30);
      expect(updated.reorderLevel, item.reorderLevel);
      expect(updated.name, item.name);
    });
  });

  group('displayName', () {
    test('falls back to the free-text name when there is no product', () {
      final item = _buildItem();
      expect(item.displayName, item.name);
    });

    test("prefers the product name when it is a product's stock", () {
      final item = StockItem(
        id: 'si2',
        name: 'Sachet bags (finished)',
        category: StockCategory.finishedGoods,
        unit: 'bags',
        quantityOnHand: 1000,
        reorderLevel: 200,
        product: sachet50cl,
      );
      expect(item.displayName, sachet50cl.label);
      expect(item.displayName, isNot(item.name));
    });
  });
}
