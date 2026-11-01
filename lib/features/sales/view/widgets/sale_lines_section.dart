import 'package:flutter/material.dart';

import '../../../products/data/models/product.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import 'sale_line_editor.dart';
import 'sale_line_form_data.dart';
import 'sale_line_table.dart';

/// The "Record sale" form's product lines — a stacked card per line on
/// phone ([SaleLineEditor]), a [SaleLineTable] with product/qty/price/
/// total as columns from the medium breakpoint up. Same underlying
/// [SaleLineFormData] either way, so switching window width mid-edit
/// (web) never loses anything already typed.
class SaleLinesSection extends StatelessWidget {
  const SaleLinesSection({
    super.key,
    required this.lines,
    required this.products,
    required this.priceEditable,
    required this.onProductChanged,
    required this.onRemove,
    required this.onAddLine,
  });

  final List<SaleLineFormData> lines;

  /// Products that can be sold (retired ones aren't offered).
  final List<Product> products;

  /// Only Owner/Admin/Manager may sell at a different price.
  final bool priceEditable;
  final void Function(SaleLineFormData line, Product product) onProductChanged;
  final void Function(SaleLineFormData line) onRemove;
  final VoidCallback onAddLine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = AppBreakpoints.isMediumOrWider(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (isWide)
              SaleLineTable(
                lines: lines,
                products: products,
                priceEditable: priceEditable,
                onProductChanged: onProductChanged,
                onRemove: onRemove,
              )
            else
              for (final line in lines) ...[
                SaleLineEditor(
                  product: line.product,
                  products: products,
                  priceEditable: priceEditable,
                  quantityController: line.quantityController,
                  unitPriceController: line.unitPriceController,
                  onProductChanged: (product) =>
                      onProductChanged(line, product),
                  onRemove: lines.length > 1 ? () => onRemove(line) : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Add product',
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.add,
              onPressed: onAddLine,
            ),
          ],
        );
      },
    );
  }
}
