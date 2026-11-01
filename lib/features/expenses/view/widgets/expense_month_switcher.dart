import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers/expenses_providers.dart';

/// Moves the expenses view between months — back up to 6 months, forward
/// no further than the current month.
class ExpenseMonthSwitcher extends ConsumerWidget {
  const ExpenseMonthSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedExpenseMonthProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final earliest = DateTime(currentMonth.year, currentMonth.month - 6, 1);
    final canGoBack = month.isAfter(earliest);
    final canGoForward = month.isBefore(currentMonth);

    void setMonth(DateTime newMonth) =>
        ref.read(selectedExpenseMonthProvider.notifier).state = newMonth;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: canGoBack
              ? () => setMonth(DateTime(month.year, month.month - 1, 1))
              : null,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: canGoForward
              ? () => setMonth(DateTime(month.year, month.month + 1, 1))
              : null,
        ),
      ],
    );
  }
}
