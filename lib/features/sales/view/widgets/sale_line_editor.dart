import 'package:flutter/material.dart';

import '../../../../core/constants/product_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';

/// One editable line in the record-sale form: product, quantity, and unit
/// price (prefilled from the catalog, editable). [onRemove] is null when
/// this is the only remaining line.
class SaleLineEditor extends StatelessWidget {
  const SaleLineEditor({
    super.key,
    required this.product,
    required this.quantityController,
    required this.unitPriceController,
    required this.onProductChanged,
    this.onRemove,
  });

  final ProductType product;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final ValueChanged<ProductType> onProductChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdownField<ProductType>(
                label: 'Product',
                value: product,
                items: ProductType.values,
                itemLabel: (item) => item.label,
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
                label: 'Quantity (bags)',
                controller: quantityController,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter a quantity.'
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField.naira(
                label: 'Unit price',
                controller: unitPriceController,
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
