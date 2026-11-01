import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../../../core/widgets/app_stock_level_bar.dart';
import '../../data/models/stock_forecast.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';
import 'stock_status_color.dart';

/// One row: item name, on-hand quantity (tabular, right-aligned), a
/// neutral level bar against the reorder point, and a status chip
/// carrying the out-of-stock/running-low/healthy meaning — the bar
/// itself is never colored by status, so a zero-stock item doesn't read
/// as a rendering glitch (a flat red stub) and a healthy one doesn't
/// double up a redundant green signal the chip already carries.
class InventoryItemTile extends ConsumerWidget {
  const InventoryItemTile({super.key, required this.item, required this.onTap});

  final StockItem item;
  final VoidCallback onTap;

  static const _statusLabel = {
    StockStatus.outOfStock: 'Out of stock',
    StockStatus.runningLow: 'Running low',
    StockStatus.healthy: 'In stock',
  };

  /// "about 6 days left" at the recent rate, or null when not used lately.
  static String? daysLeftText(StockForecast? forecast) {
    final days = forecast?.daysLeft;
    if (days == null) return null;
    if (days < 1) return 'runs out today';
    final whole = days.floor();
    return whole == 1 ? 'about 1 day left' : 'about $whole days left';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = item.status;
    final forecast = ref.watch(
      stockForecastProvider.select((value) => value.valueOrNull?[item.id]),
    );
    final daysLeft = daysLeftText(forecast);
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
                Expanded(
                  child: Text(
                    [
                      'Reorder at ${formatQuantity(item.reorderLevel, item.unit)}',
                      ?daysLeft,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (forecast?.runningOut ?? false)
                          ? AppColors.warningFg
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
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
