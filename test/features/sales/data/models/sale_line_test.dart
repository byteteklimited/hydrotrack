import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/sales/data/models/sale_line.dart';

import '../../../../helpers/test_products.dart';

void main() {
  group('SaleLine JSON', () {
    test('round-trips through fromJson(toJson(x))', () {
      const line = SaleLine(product: sachet50cl, quantity: 40, unitPrice: 400);
      final roundTripped = SaleLine.fromJson(line.toJson());
      expect(roundTripped.product, line.product);
      expect(roundTripped.quantity, line.quantity);
      expect(roundTripped.unitPrice, line.unitPrice);
    });
  });

  group('lineTotal', () {
    test('multiplies quantity by unit price', () {
      const line = SaleLine(product: bottle75cl, quantity: 10, unitPrice: 150);
      expect(line.lineTotal, 1500);
    });
  });
}
