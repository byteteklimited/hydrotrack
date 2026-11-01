import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/production/data/models/production_recipe.dart';

import '../../../../helpers/test_products.dart';

void main() {
  group('ProductionRecipe JSON', () {
    test('fromJson reads the joined stock_items name/unit', () {
      final recipe = ProductionRecipe.fromJson({
        'id': 'rec1',
        ...sachet50cl.toRecordJson(),
        'raw_material_item_id': 'si1',
        'quantity_used': 1,
        'per_bags': 1000,
        'stock_items': {'name': 'Nylon rolls', 'unit': 'rolls'},
      });
      expect(recipe.rawMaterialName, 'Nylon rolls');
      expect(recipe.rawMaterialUnit, 'rolls');
      expect(recipe.product, sachet50cl);
    });

    test('fromJson falls back when stock_items is missing', () {
      final recipe = ProductionRecipe.fromJson({
        'id': 'rec1',
        ...sachet50cl.toRecordJson(),
        'raw_material_item_id': 'si1',
        'quantity_used': 1,
        'per_bags': 1000,
      });
      expect(recipe.rawMaterialName, 'Unknown material');
      expect(recipe.rawMaterialUnit, '');
    });
  });

  group('quantityPerBag', () {
    test('divides quantityUsed by perBags', () {
      final recipe = ProductionRecipe(
        id: 'rec1',
        product: sachet50cl,
        rawMaterialItemId: 'si1',
        rawMaterialName: 'Nylon rolls',
        rawMaterialUnit: 'rolls',
        quantityUsed: 1,
        perBags: 1000,
      );
      expect(recipe.quantityPerBag, 0.001);
    });

    test('scales correctly for a fractional quantityUsed', () {
      final recipe = ProductionRecipe(
        id: 'rec2',
        product: sachet50cl,
        rawMaterialItemId: 'si2',
        rawMaterialName: 'Treatment chemical',
        rawMaterialUnit: 'litres',
        quantityUsed: 2.5,
        perBags: 500,
      );
      expect(recipe.quantityPerBag, 0.005);
    });
  });
}
