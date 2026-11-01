import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/expense.dart';
import '../repositories/expenses_repository.dart';
import '../repositories/offline_expenses_repository.dart';

/// The active [ExpensesRepository] implementation.
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final remote = SupabaseExpensesRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineExpensesRepository(remote, offline);
});

/// Expenses in the selected month, most recent first. Only that month is
/// loaded.
final expensesProvider = FutureProvider<List<Expense>>((ref) {
  final month = ref.watch(selectedExpenseMonthProvider);
  return ref
      .watch(expensesRepositoryProvider)
      .fetchExpenses(from: month, to: DateTime(month.year, month.month + 1));
});

/// The month currently shown, as its first day. Defaults to the current
/// month; the month switcher moves it backward/forward.
final selectedExpenseMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

bool _isInMonth(DateTime date, DateTime month) =>
    date.year == month.year && date.month == month.month;

/// Expenses for the selected month, most recent first.
final expensesForSelectedMonthProvider = Provider<AsyncValue<List<Expense>>>((
  ref,
) {
  final month = ref.watch(selectedExpenseMonthProvider);
  return ref
      .watch(expensesProvider)
      .whenData(
        (expenses) => expenses.where((e) => _isInMonth(e.date, month)).toList(),
      );
});

/// The selected month's total spend and its breakdown by category
/// (largest first) — so it's obvious at a glance what's eating the
/// budget.
class ExpenseSummary {
  const ExpenseSummary({required this.monthTotal, required this.byCategory});

  final num monthTotal;
  final Map<ExpenseCategory, num> byCategory;
}

final expenseSummaryProvider = Provider<AsyncValue<ExpenseSummary>>((ref) {
  return ref.watch(expensesForSelectedMonthProvider).whenData((expenses) {
    final byCategory = <ExpenseCategory, num>{};
    num total = 0;
    for (final expense in expenses) {
      byCategory.update(
        expense.category,
        (sum) => sum + expense.amount,
        ifAbsent: () => expense.amount,
      );
      total += expense.amount;
    }
    final sortedEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ExpenseSummary(
      monthTotal: total,
      byCategory: {for (final entry in sortedEntries) entry.key: entry.value},
    );
  });
});

/// Drives "Record expense": loading while the save is in flight, error
/// (most commonly no connection) if it fails.
class RecordExpenseController extends ActionController {
  RecordExpenseController(this._ref);

  final Ref _ref;

  Future<void> record(Expense expense) {
    return guard(() async {
      await _ref.read(expensesRepositoryProvider).recordExpense(expense);
      _ref.invalidate(expensesProvider);
    });
  }
}

final recordExpenseControllerProvider =
    StateNotifierProvider<RecordExpenseController, AsyncValue<void>>(
      (ref) => RecordExpenseController(ref),
    );
