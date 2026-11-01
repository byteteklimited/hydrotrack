import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/expense.dart';
import '../../data/providers/expenses_providers.dart';
import '../widgets/expense_category_breakdown.dart';
import '../widgets/expense_day_section.dart';
import '../widgets/expense_month_switcher.dart';
import 'expense_detail_screen.dart';
import 'record_expense_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// Expenses leads with this month's total and a by-category breakdown, so
/// the owner can see what's eating the budget, then the month's entries
/// grouped by day.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(expenseSummaryProvider);
    final expensesAsync = ref.watch(expensesForSelectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: AppButton(
        label: 'Record expense',
        leadingIcon: Icons.add,
        onPressed: () =>
            showAppModal(context, builder: (_) => const RecordExpenseScreen()),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(expensesProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.xxl,
              ),
              children: [
                switch (summaryAsync) {
                  AsyncData(:final value) when value.byCategory.isNotEmpty =>
                    Column(
                      children: [
                        AppCard(
                          child: AppStat(
                            label: 'THIS MONTH',
                            value: formatNaira(value.monthTotal),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ExpenseCategoryBreakdown(byCategory: value.byCategory),
                      ],
                    ),
                  AsyncError() => AppErrorState(
                    message:
                        "Couldn't load expenses. Check your connection and try again.",
                    onRetry: () => ref.invalidate(expensesProvider),
                  ),
                  _ => const AppLoading(message: 'Loading expenses…'),
                },
                const SizedBox(height: AppSpacing.lg),
                const ExpenseMonthSwitcher(),
                const SizedBox(height: AppSpacing.sm),
                switch (expensesAsync) {
                  AsyncData(:final value) when value.isEmpty => const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xl),
                    child: AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses',
                      message:
                          'No expenses recorded this month. Tap + to record one.',
                    ),
                  ),
                  AsyncData(:final value) => Column(
                    children: [
                      for (final entry in _groupByDay(value).entries) ...[
                        ExpenseDaySection(
                          date: entry.key,
                          expenses: entry.value,
                          onExpenseTap: (expense) => showAppModal(
                            context,
                            builder: (_) =>
                                ExpenseDetailScreen(expense: expense),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                  _ => const SizedBox.shrink(),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Map<DateTime, List<Expense>> _groupByDay(List<Expense> expenses) {
    final map = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      map.putIfAbsent(dateOnly(expense.date), () => []).add(expense);
    }
    final sortedDays = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final day in sortedDays) day: map[day]!};
  }
}
