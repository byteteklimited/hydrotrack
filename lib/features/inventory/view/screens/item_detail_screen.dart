import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';
import '../widgets/batch_list_card.dart';
import '../widgets/movement_history_card.dart';
import '../widgets/stock_status_color.dart';
import 'add_stock_item_screen.dart';
import 'add_stock_screen.dart';
import 'adjust_count_screen.dart';

/// Same reasoning as the production list: content reads best at a
/// bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 720;

/// Current level, reorder level, and the full movement ledger for one
/// item — the audit trail behind its stock count.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(stockItemsProvider);

    return itemsAsync.when(
      data: (items) {
        final item = items.firstWhere((i) => i.id == itemId);
        return _ItemDetailBody(item: item);
      },
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              "Couldn't load this item. Check your connection and try again.",
          onRetry: () => ref.invalidate(stockItemsProvider),
        ),
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  const _ItemDetailBody({required this.item});

  final StockItem item;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this item?',
      message:
          '${item.displayName} — this removes it from the catalog entirely. '
          "This can't be undone.",
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await ref
        .read(stockActionControllerProvider.notifier)
        .deleteItem(item.id);
    if (!context.mounted) return;

    if (!success) {
      final error = ref.read(stockActionControllerProvider).error;
      final reason = readableErrorMessage(error);
      showActionErrorSnackBar(context, message: reason);
      return;
    }
    // The result (not a snackbar here) tells the list screen to show the
    // confirmation — this Scaffold, and its ScaffoldMessenger, are gone
    // the moment this pop completes.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(itemMovementsProvider(item.id));
    final batchesAsync = ref.watch(itemBatchesProvider(item.id));
    final role = ref.watch(authStateProvider)?.role;
    final canManage = role?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayName),
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit item',
              onPressed: () => showAppModal(
                context,
                builder: (_) => AddStockItemScreen(existingItem: item),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete item',
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(stockItemsProvider.future),
              ref.refresh(itemMovementsProvider(item.id).future),
              ref.refresh(itemBatchesProvider(item.id).future),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppSpacing.lg,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: AppStat(
                          label: 'Current level',
                          value: '${item.quantityOnHand} ${item.unit}',
                          valueColor: item.status.color,
                        ),
                      ),
                      Expanded(
                        child: AppStat(
                          label: 'Reorder level',
                          value: '${item.reorderLevel} ${item.unit}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Add stock',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddStockScreen(item: item),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Adjust count',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdjustCountScreen(item: item),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Batches', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                batchesAsync.when(
                  data: (batches) =>
                      BatchListCard(batches: batches, unit: item.unit),
                  loading: () => const AppLoadingCompact(),
                  error: (error, stackTrace) => AppErrorState(
                    message:
                        "Couldn't load batches. Check your connection and try again.",
                    onRetry: () => ref.invalidate(itemBatchesProvider(item.id)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Movement history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                movementsAsync.when(
                  data: (movements) => MovementHistoryCard(
                    movements: movements,
                    unit: item.unit,
                  ),
                  loading: () => const AppLoadingCompact(),
                  error: (error, stackTrace) => AppErrorState(
                    message:
                        "Couldn't load movement history. Check your connection and try again.",
                    onRetry: () =>
                        ref.invalidate(itemMovementsProvider(item.id)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
