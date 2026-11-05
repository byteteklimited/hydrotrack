import 'package:flutter/material.dart';

import '../../../products/data/models/product.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';

/// One editable line in the record-sale form: product, quantity, and unit
/// price (filled in from the product's price; editable only when
/// [priceEditable]). [onRemove] is null when this is the only line.
class SaleLineEditor extends StatelessWidget {
  const SaleLineEditor({
    super.key,
    required this.product,
    required this.products,
    required this.quantityController,
    required this.unitPriceController,
    required this.onProductChanged,
    required this.priceEditable,
    this.onRemove,
  });

  final Product? product;
  final List<Product> products;
  final bool priceEditable;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final ValueChanged<Product> onProductChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdownField<Product?>(
                label: 'Product',
                value: product,
                items: products,
                itemLabel: (item) => item?.label ?? '',
                onChanged: (value) => onProductChanged(value!),
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove line',
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField.quantity(
                hint: 'e.g. 20',
                label: 'Quantity (${product?.unit ?? 'bags'})',
                controller: quantityController,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter a quantity.'
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.naira(
                hint: 'e.g. 300',
                label: 'Unit price',
                controller: unitPriceController,
                enabled: priceEditable,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter a unit price.'
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
