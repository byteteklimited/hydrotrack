import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_month_switcher.dart';
import '../../data/providers/expenses_providers.dart';

/// Moves the expenses view between months — back up to 6 months, forward
/// no further than the current month.
class ExpenseMonthSwitcher extends ConsumerWidget {
  const ExpenseMonthSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppMonthSwitcher(
      month: ref.watch(selectedExpenseMonthProvider),
      onChanged: (month) =>
          ref.read(selectedExpenseMonthProvider.notifier).state = month,
    );
  }
}
