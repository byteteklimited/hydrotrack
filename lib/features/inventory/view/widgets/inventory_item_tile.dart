import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../../../core/widgets/app_stock_level_bar.dart';
import '../../data/models/stock_item.dart';
import 'stock_status_color.dart';

/// One row: item name, on-hand quantity (tabular, right-aligned), a
/// neutral level bar against the reorder point, and a status chip
/// carrying the out-of-stock/running-low/healthy meaning — the bar
/// itself is never colored by status, so a zero-stock item doesn't read
/// as a rendering glitch (a flat red stub) and a healthy one doesn't
/// double up a redundant green signal the chip already carries.
class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile({super.key, required this.item, required this.onTap});

  final StockItem item;
  final VoidCallback onTap;

  static const _statusLabel = {
    StockStatus.outOfStock: 'Out of stock',
    StockStatus.runningLow: 'Running low',
    StockStatus.healthy: 'In stock',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item.status;
    final rawFraction = item.reorderLevel == 0
        ? 1.0
        : (item.quantityOnHand / (item.reorderLevel * 2)).clamp(0.0, 1.0);
    final fraction = item.quantityOnHand == 0
        ? 0.0
        : (rawFraction < 0.04 ? 0.04 : rawFraction);
    final reorderFraction = item.reorderLevel == 0 ? null : 0.5;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  formatQuantity(item.quantityOnHand, item.unit),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AppStockLevelBar(
              fraction: fraction,
              reorderFraction: reorderFraction,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reorder at ${formatQuantity(item.reorderLevel, item.unit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                AppStatusTag(
                  label: _statusLabel[status]!,
                  color: status.color ?? AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
