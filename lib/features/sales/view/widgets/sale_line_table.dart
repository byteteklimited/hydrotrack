import 'package:flutter/material.dart';

import '../../../products/data/models/product.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import 'sale_line_form_data.dart';
import 'sale_line_table_row.dart';

/// Column labels for [SaleLineTable] — same flex widths as
/// [SaleLineTableRow] so the header lines up with every row below it.
class _SaleLineTableHeader extends StatelessWidget {
  const _SaleLineTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Product', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('Qty (bags)', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('Unit price', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('Total', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: saleLineTableRemoveColumnWidth),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of a sale's product lines — product,
/// quantity, unit price, and total as aligned columns, inside the app's
/// one signature surface ([AppCard]) rather than a raw table so it still
/// reads as part of this app, not a generic data grid.
class SaleLineTable extends StatelessWidget {
  const SaleLineTable({
    super.key,
    required this.lines,
    required this.products,
    required this.priceEditable,
    required this.onProductChanged,
    required this.onRemove,
  });

  final List<SaleLineFormData> lines;
  final List<Product> products;
  final bool priceEditable;
  final void Function(SaleLineFormData line, Product product) onProductChanged;
  final void Function(SaleLineFormData line) onRemove;

  @override
  Widget build(BuildContext context) {
    final canRemove = lines.length > 1;

    return AppCard(
      child: Column(
        children: [
          const _SaleLineTableHeader(),
          const Divider(),
          for (var i = 0; i < lines.length; i++) ...[
            SaleLineTableRow(
              line: lines[i],
              products: products,
              priceEditable: priceEditable,
              onProductChanged: (product) =>
                  onProductChanged(lines[i], product),
              onRemove: canRemove ? () => onRemove(lines[i]) : null,
            ),
            if (i != lines.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}
