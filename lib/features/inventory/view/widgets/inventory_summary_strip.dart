import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_stat_tile.dart';
import '../../../../core/widgets/app_stat_tile_grid.dart';
import '../../data/models/stock_batch.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';

/// Out of stock / running low / expiring-soon counts, and when stock was
/// last physically counted — the at-a-glance read before scrolling into
/// the lists below. Total stock value belongs here too but needs unit
/// cost on the catalog first, which doesn't exist yet — left out rather
/// than shown as a meaningless ₦0.
class InventorySummaryStrip extends ConsumerWidget {
  const InventorySummaryStrip({super.key, required this.items});

  final List<StockItem> items;

  static const double _maxTileWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outOfStockCount = items
        .where((i) => i.status == StockStatus.outOfStock)
        .length;
    final runningLowCount = items
        .where((i) => i.status == StockStatus.runningLow)
        .length;
    final lastCountAsync = ref.watch(lastStockCountDateProvider);
    final activeBatchesAsync = ref.watch(activeBatchesProvider);
    final expiringOrExpiredCount =
        activeBatchesAsync.valueOrNull
            ?.where((b) => b.expiryStatus != BatchExpiryStatus.none)
            .length ??
        0;

    return AppStatTileGrid(
      maxTileWidth: _maxTileWidth,
      tiles: [
        AppStatTile(
          icon: Icons.remove_circle_outline,
          label: 'Out of stock',
          value: '$outOfStockCount',
          iconColor: outOfStockCount > 0 ? AppColors.moneyOut : null,
        ),
        AppStatTile(
          icon: Icons.trending_down,
          label: 'Running low',
          value: '$runningLowCount',
          iconColor: runningLowCount > 0 ? AppColors.lowStockWarning : null,
        ),
        AppStatTile(
          icon: Icons.event_busy_outlined,
          label: 'Expiring soon',
          value: '$expiringOrExpiredCount',
          iconColor: expiringOrExpiredCount > 0
              ? AppColors.lowStockWarning
              : null,
        ),
        AppStatTile(
          icon: Icons.fact_check_outlined,
          label: 'Last stock count',
          value: lastCountAsync.when(
            data: (date) => date == null ? 'Never' : formatRelativeDay(date),
            loading: () => '…',
            error: (error, stackTrace) => '—',
          ),
          valueColor: lastCountAsync.valueOrNull == null
              ? AppColors.textSecondary
              : null,
        ),
      ],
    );
  }
}
