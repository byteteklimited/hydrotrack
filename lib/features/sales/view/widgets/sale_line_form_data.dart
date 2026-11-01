import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../../products/data/models/product.dart';

/// One editable product line's live form state in "Record sale" — holds
/// its own controllers so the quantity/price fields keep focus and
/// cursor position across rebuilds triggered elsewhere on the form.
/// Shared between the mobile card layout and the tablet/desktop table,
/// so both render the exact same underlying state.
class SaleLineFormData {
  SaleLineFormData()
    : quantityController = TextEditingController(),
      unitPriceController = TextEditingController();

  /// Null until the organization's products have loaded.
  Product? product;

  /// The product's price for this customer type, which [unitPriceController]
  /// starts at (only managers may change it).
  num listPrice = 0;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  /// Picks [newProduct] and fills in its price for the customer type.
  void choose(Product newProduct, {required bool distributor}) {
    product = newProduct;
    listPrice = newProduct.priceFor(distributor: distributor);
    unitPriceController.text = NumberFormat.decimalPattern(
      'en_NG',
    ).format(listPrice);
  }

  num get lineTotal =>
      (int.tryParse(quantityController.text) ?? 0) *
      parseNairaText(unitPriceController.text);

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
