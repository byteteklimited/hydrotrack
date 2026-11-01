import 'package:flutter/material.dart';

import '../../../../core/constants/product_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'sale_line_form_data.dart';

/// Column widths shared with [SaleLineTableHeader] so header and rows
/// line up exactly. The remove button gets a fixed width rather than a
/// flex share — it shouldn't grow with the table.
const saleLineTableRemoveColumnWidth = 48.0;

/// One line in the tablet/desktop "Record sale" table: product, qty,
/// unit price, and the computed total, as aligned columns instead of
/// [SaleLineEditor]'s stacked mobile card.
class SaleLineTableRow extends StatelessWidget {
  const SaleLineTableRow({
    super.key,
    required this.line,
    required this.onProductChanged,
    this.onRemove,
  });

  final SaleLineFormData line;
  final ValueChanged<ProductType> onProductChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: AppDropdownField<ProductType>(
              label: 'Product',
              value: line.product,
              items: ProductType.values,
              itemLabel: (item) => item.label,
              onChanged: (value) => onProductChanged(value!),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppTextField.quantity(
              label: 'Quantity (bags)',
              controller: line.quantityController,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter a quantity.' : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppTextField.naira(
              label: 'Unit price',
              controller: line.unitPriceController,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Enter a unit price.'
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatNaira(line.lineTotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: saleLineTableRemoveColumnWidth,
            child: onRemove == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove line',
                    onPressed: onRemove,
                  ),
          ),
        ],
      ),
    );
  }
}
