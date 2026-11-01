import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/models/sale.dart';
import '../../data/providers/sales_providers.dart';
import '../widgets/sale_list_tile.dart';
import '../widgets/sales_day_switcher.dart';
import '../widgets/sales_today_card.dart';
import 'receipt_screen.dart';
import 'record_sale_screen.dart';

/// Same reasoning as Production/Inventory's list screens: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// Sales leads with today's takings, then the sales for whichever day the
/// switcher is set to.
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  Future<void> _recordSale(BuildContext context, WidgetRef ref) async {
    // RecordSaleScreen pops with the saved Sale once it closes itself —
    // only then is it safe to open the receipt as its own modal, rather
    // than trying to push it from inside a sheet that's already in the
    // middle of closing.
    final savedSale = await showAppModal<Sale>(
      context,
      builder: (_) => const RecordSaleScreen(),
    );
    if (savedSale == null || !context.mounted) return;

    // `recordSale`'s own write already invalidates `salesProvider`, but
    // invalidation alone doesn't guarantee the refetch has landed by the
    // time the receipt below reads it — awaiting it here does, so it can
    // safely find `savedSale.id` on its very first build instead of
    // racing it.
    ref.invalidate(salesProvider);
    await ref.read(salesProvider.future);
    if (!context.mounted) return;

    await showAppModal(
      context,
      builder: (_) => ReceiptScreen(saleId: savedSale.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(todaysSalesTotalsProvider);
    final dailySalesAsync = ref.watch(salesForSelectedDayProvider);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // On a wide screen, "Record sale" moves into the header next to
        // the day switcher, in place of the floating FAB — the FAB stays
        // on a phone-width screen, where there's no spare header row for
        // it to sit in anyway. Measured once here (not inside the body's
        // own LayoutBuilder below) so the header button and the FAB can
        // never disagree about which width band they're in.
        final isWide = AppBreakpoints.isMediumOrWider(
          outerConstraints.maxWidth,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Sales')),
          floatingActionButton: isWide
              ? null
              : AppButton(
                  label: 'Record sale',
                  leadingIcon: Icons.add,
                  onPressed: () => _recordSale(context, ref),
                ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;

              return RefreshIndicator(
                onRefresh: () => ref.refresh(salesProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.lg,
                    horizontalPadding,
                    AppSpacing.xxl,
                  ),
                  children: [
                    switch (totalsAsync) {
                      AsyncData(:final value) => SalesTodayCard(totals: value),
                      AsyncError() => AppErrorState(
                        message:
                            "Couldn't load today's totals. Check your connection and try again.",
                        onRetry: () => ref.invalidate(salesProvider),
                      ),
                      _ => const AppLoading(),
                    },
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: SalesDaySwitcher()),
                        if (isWide) ...[
                          const SizedBox(width: AppSpacing.md),
                          AppButton(
                            label: 'Record sale',
                            leadingIcon: Icons.add,
                            onPressed: () => _recordSale(context, ref),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    switch (dailySalesAsync) {
                      AsyncData(:final value) =>
                        value.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.xl),
                                child: AppEmptyState(
                                  icon: Icons.point_of_sale_outlined,
                                  title: 'No sales recorded',
                                  message:
                                      'No sales recorded for this day. Record a sale to get started.',
                                ),
                              )
                            : AppCard(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < value.length; i++) ...[
                                      SaleListTile(
                                        sale: value[i],
                                        onTap: () => showAppModal(
                                          context,
                                          builder: (_) => ReceiptScreen(
                                            saleId: value[i].id,
                                          ),
                                        ),
                                      ),
                                      if (i != value.length - 1)
                                        const Divider(),
                                    ],
                                    const Divider(),
                                    _DailyTotalRow(sales: value),
                                  ],
                                ),
                              ),
                      AsyncError() => AppErrorState(
                        message:
                            "Couldn't load sales for this day. Check your connection and try again.",
                        onRetry: () => ref.invalidate(salesProvider),
                      ),
                      _ => const AppLoading(),
                    },
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Sum of the day's sales, display-only — computed from the list already
/// loaded for this screen, not a separate fetch. Voided sales drop out,
/// same as every other total in the app.
class _DailyTotalRow extends StatelessWidget {
  const _DailyTotalRow({required this.sales});

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final total = sales
        .where((s) => !s.isVoided)
        .fold<num>(0, (sum, s) => sum + s.total);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Daily total',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            formatNaira(total),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
