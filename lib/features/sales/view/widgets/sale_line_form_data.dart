import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/product_catalog.dart';

/// Strips the thousands-grouping `AppTextField.naira` adds live, so the
/// typed amount can be read back as a number.
num parseNairaText(String text) => num.tryParse(text.replaceAll(',', '')) ?? 0;

/// One editable product line's live form state in "Record sale" — holds
/// its own controllers so the quantity/price fields keep focus and
/// cursor position across rebuilds triggered elsewhere on the form.
/// Shared between the mobile card layout and the tablet/desktop table,
/// so both render the exact same underlying state.
class SaleLineFormData {
  SaleLineFormData()
    : product = ProductType.sachet50cl,
      quantityController = TextEditingController(),
      unitPriceController = TextEditingController(
        text: NumberFormat.decimalPattern(
          'en_NG',
        ).format(ProductType.sachet50cl.defaultUnitPrice),
      );

  ProductType product;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  num get lineTotal =>
      (int.tryParse(quantityController.text) ?? 0) *
      parseNairaText(unitPriceController.text);

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
