import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/stock_item.dart';
import '../../data/providers/inventory_providers.dart';
import '../widgets/inventory_items_card.dart';
import '../widgets/inventory_summary_strip.dart';
import 'add_stock_item_screen.dart';
import 'item_detail_screen.dart';

/// Raw materials and finished goods, each leading with what's about to
/// run out. Tabs on phone/tablet (one category at a time); side by side
/// from the expanded breakpoint up, where there's room to show both at
/// once instead of making the owner switch back and forth.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(stockItemsProvider);
    final role = ref.watch(authStateProvider)?.role;
    final canManage = role?.canManage ?? false;

    Future<void> openItem(StockItem item) async {
      final deleted = await showAppModal<bool>(
        context,
        builder: (_) => ItemDetailScreen(itemId: item.id),
      );
      if (deleted == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.displayName} deleted')));
      }
    }

    final fab = canManage
        ? AppButton(
            label: 'Add item',
            leadingIcon: Icons.add,
            onPressed: () => showAppModal(
              context,
              builder: (_) => const AddStockItemScreen(),
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = AppBreakpoints.isExpanded(constraints.maxWidth);

        if (isExpanded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inventory'),
              actions: [
                if (fab != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    child: fab,
                  ),
              ],
            ),
            body: itemsAsync.when(
              data: (items) =>
                  _ExpandedInventoryBody(items: items, onItemTap: openItem),
              loading: () => const AppLoading(message: 'Loading stock levels…'),
              error: (error, stackTrace) => AppErrorState(
                message:
                    "Couldn't load inventory. Check your connection and try again.",
                onRetry: () => ref.invalidate(stockItemsProvider),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Inventory'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Raw materials'),
                  Tab(text: 'Finished goods'),
                ],
              ),
            ),
            floatingActionButton: fab,
            body: itemsAsync.when(
              data: (items) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      children: [
                        InventorySummaryStrip(items: items),
                        if (_neverStocked(items)) ...[
                          const SizedBox(height: AppSpacing.md),
                          const _NeverStockedBanner(),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _CategoryTab(
                          items: items
                              .where(
                                (i) => i.category == StockCategory.rawMaterial,
                              )
                              .toList(),
                          onItemTap: openItem,
                        ),
                        _CategoryTab(
                          items: items
                              .where(
                                (i) =>
                                    i.category == StockCategory.finishedGoods,
                              )
                              .toList(),
                          onItemTap: openItem,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const AppLoading(message: 'Loading stock levels…'),
              error: (error, stackTrace) => AppErrorState(
                message:
                    "Couldn't load inventory. Check your connection and try again.",
                onRetry: () => ref.invalidate(stockItemsProvider),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _neverStocked(List<StockItem> items) =>
      items.isNotEmpty && items.every((i) => i.quantityOnHand == 0);
}

/// A slim, quiet note — not a colored banner — since this isn't a
/// warning about anything, just a prompt for what to do first.
class _NeverStockedBanner extends StatelessWidget {
  const _NeverStockedBanner();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Record opening stock for each item to start tracking.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// One tab's content: out of stock, then running low, then healthy.
class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({required this.items, required this.onItemTap});

  final List<StockItem> items;
  final ValueChanged<StockItem> onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(stockItemsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [_CategoryGroup(items: items, onItemTap: onItemTap)],
      ),
    );
  }
}

/// Both categories side by side, each under its own heading — the
/// expanded-width replacement for the tab strip.
class _ExpandedInventoryBody extends ConsumerWidget {
  const _ExpandedInventoryBody({required this.items, required this.onItemTap});

  final List<StockItem> items;
  final ValueChanged<StockItem> onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawMaterials = items
        .where((i) => i.category == StockCategory.rawMaterial)
        .toList();
    final finishedGoods = items
        .where((i) => i.category == StockCategory.finishedGoods)
        .toList();
    final neverStocked =
        items.isNotEmpty && items.every((i) => i.quantityOnHand == 0);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(stockItemsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          InventorySummaryStrip(items: items),
          if (neverStocked) ...[
            const SizedBox(height: AppSpacing.md),
            const _NeverStockedBanner(),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryColumn(
                  heading: 'Raw materials',
                  items: rawMaterials,
                  onItemTap: onItemTap,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _CategoryColumn(
                  heading: 'Finished goods',
                  items: finishedGoods,
                  onItemTap: onItemTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryColumn extends StatelessWidget {
  const _CategoryColumn({
    required this.heading,
    required this.items,
    required this.onItemTap,
  });

  final String heading;
  final List<StockItem> items;
  final ValueChanged<StockItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _CategoryGroup(items: items, onItemTap: onItemTap),
      ],
    );
  }
}

/// Out of stock, then running low, then healthy — the one place this
/// grouping logic lives, shared by the tabbed and side-by-side layouts.
class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.items, required this.onItemTap});

  final List<StockItem> items;
  final ValueChanged<StockItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nothing here yet',
        message: 'Add an item to start this category\'s catalog.',
      );
    }

    final outOfStock = items
        .where((i) => i.status == StockStatus.outOfStock)
        .toList();
    final runningLow = items
        .where((i) => i.status == StockStatus.runningLow)
        .toList();
    final healthy = items
        .where((i) => i.status == StockStatus.healthy)
        .toList();

    return Column(
      children: [
        if (outOfStock.isNotEmpty) ...[
          InventoryItemsCard(
            title: 'Out of stock',
            items: outOfStock,
            onItemTap: onItemTap,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (runningLow.isNotEmpty) ...[
          InventoryItemsCard(
            title: 'Running low',
            items: runningLow,
            onItemTap: onItemTap,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (healthy.isNotEmpty)
          InventoryItemsCard(
            title: 'Healthy',
            items: healthy,
            onItemTap: onItemTap,
          ),
      ],
    );
  }
}
