import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/expense.dart';
import 'expense_table_row.dart';

class _ExpenseTableHeader extends StatelessWidget {
  const _ExpenseTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('DESCRIPTION', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('CATEGORY', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('AMOUNT', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of one day's expenses — description
/// (with its category icon), category, method, and amount as aligned
/// columns, zebra-striped with the app's reserved `tableRowTint`. No
/// outer `AppCard` here on purpose — [ExpenseDaySection], which already
/// wraps each day in its own titled card, provides that; nesting a
/// second card inside it would double the border/elevation for no
/// reason.
class ExpenseTable extends StatelessWidget {
  const ExpenseTable({
    super.key,
    required this.expenses,
    required this.onTapExpense,
  });

  final List<Expense> expenses;
  final ValueChanged<Expense> onTapExpense;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ExpenseTableHeader(),
        const Divider(height: 1),
        for (var i = 0; i < expenses.length; i++)
          ExpenseTableRow(
            expense: expenses[i],
            tinted: i.isOdd,
            onTap: () => onTapExpense(expenses[i]),
          ),
      ],
    );
  }
}
