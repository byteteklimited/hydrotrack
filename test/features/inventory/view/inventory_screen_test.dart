import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/auth/data/providers/auth_providers.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_item.dart';
import 'package:hydrotrack/features/inventory/data/providers/inventory_providers.dart';
import 'package:hydrotrack/features/inventory/view/screens/inventory_screen.dart';

StockItem _item(
  String id,
  StockCategory category, {
  int quantity = 0,
  ProductType? product,
}) {
  return StockItem(
    id: id,
    name: id,
    category: category,
    unit: 'bags',
    quantityOnHand: quantity,
    reorderLevel: 10,
    productType: product,
  );
}

/// A brand-new organization: no raw materials, the four starter
/// products all at zero.
final _newOrganization = [
  for (final product in ProductType.values)
    _item(product.name, StockCategory.finishedGoods, product: product),
];

/// Every stock status in both categories.
final _stocked = [
  _item('Preforms', StockCategory.rawMaterial, quantity: 500),
  _item('Labels', StockCategory.rawMaterial, quantity: 4),
  _item('Caps', StockCategory.rawMaterial),
  _item(
    'sachet',
    StockCategory.finishedGoods,
    quantity: 300,
    product: ProductType.sachet50cl,
  ),
  _item(
    'bottle',
    StockCategory.finishedGoods,
    quantity: 5,
    product: ProductType.bottle75cl,
  ),
];

Future<void> _pumpInventory(
  WidgetTester tester,
  List<StockItem> items,
  Size window,
) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stockItemsProvider.overrideWith((ref) async => items),
        authStateProvider.overrideWith(
          (ref) => const StaffUser(
            id: 'owner',
            fullName: 'Demo Owner',
            role: StaffRole.owner,
            phone: '',
          ),
        ),
      ],
      child: const MaterialApp(home: InventoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (layout, window) in [
    ('side-by-side (desktop)', const Size(1400, 900)),
    ('tabbed (phone)', const Size(390, 800)),
  ]) {
    for (final (state, items) in [
      ('a new organization', _newOrganization),
      ('stocked items', _stocked),
    ]) {
      testWidgets('Inventory $layout lays out $state without errors', (
        tester,
      ) async {
        await _pumpInventory(tester, items, window);

        expect(tester.takeException(), isNull);
        expect(find.text('Inventory'), findsWidgets);
      });
    }
  }
}
