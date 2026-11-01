import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/providers/finance_providers.dart';
import '../widgets/cash_counts_card.dart';
import '../widgets/cash_ledger_section.dart';
import '../widgets/finance_day_switcher.dart';
import '../widgets/finance_filter_chips.dart';
import '../widgets/finance_flow_card.dart';
import '../widgets/finance_position_card.dart';
import 'entry_detail_screen.dart';
import 'record_entry_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// Finance leads with position (cash in hand, bank balance), then today's
/// flow, then the day's ledger.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(financePositionProvider);
    final totalsAsync = ref.watch(financeTodayTotalsProvider);
    final entriesAsync = ref.watch(filteredEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      floatingActionButton: AppButton(
        label: 'Record entry',
        leadingIcon: Icons.add,
        onPressed: () =>
            showAppModal(context, builder: (_) => const RecordEntryScreen()),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(financePositionProvider.future),
              ref.refresh(cashEntriesProvider.future),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.xxl,
              ),
              children: [
                switch (positionAsync) {
                  AsyncData(:final value) => FinancePositionCard(
                    position: value,
                  ),
                  AsyncError() => AppErrorState(
                    message:
                        "Couldn't load your cash position. Check your connection and try again.",
                    onRetry: () => ref.invalidate(financePositionProvider),
                  ),
                  _ => const AppLoading(),
                },
                const SizedBox(height: AppSpacing.md),
                switch (totalsAsync) {
                  AsyncData(:final value) => FinanceFlowCard(totals: value),
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(height: AppSpacing.md),
                const CashCountsCard(),
                const SizedBox(height: AppSpacing.sm),
                const FinanceDaySwitcher(),
                const SizedBox(height: AppSpacing.sm),
                const FinanceFilterChips(),
                const SizedBox(height: AppSpacing.md),
                switch (entriesAsync) {
                  AsyncData(:final value) when value.isEmpty => const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xl),
                    child: AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Nothing recorded',
                      message:
                          'Nothing recorded today yet. Money in and out will appear here as the day goes.',
                    ),
                  ),
                  AsyncData(:final value) => CashLedgerSection(
                    entries: value,
                    onTapEntry: (entry) => showAppModal(
                      context,
                      builder: (_) => EntryDetailScreen(entry: entry),
                    ),
                  ),
                  AsyncError() => AppErrorState(
                    message:
                        "Couldn't load entries for this day. Check your connection and try again.",
                    onRetry: () => ref.invalidate(cashEntriesProvider),
                  ),
                  _ => const AppLoading(),
                },
              ],
            ),
          );
        },
      ),
    );
  }
}
