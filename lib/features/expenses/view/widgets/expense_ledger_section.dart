import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../data/models/expense.dart';
import 'expense_table.dart';
import 'expense_tile.dart';

/// One day's expenses — a stacked card per entry on phone ([ExpenseTile]),
/// an [ExpenseTable] with description/category/method/amount as columns
/// from the medium breakpoint up. Same mobile-vs-table switch
/// `CashLedgerSection`/`DebtLedgerSection` already established. No
/// `AppCard` here either way — [ExpenseDaySection] already provides the
/// day's own titled card around whichever of these renders.
class ExpenseLedgerSection extends StatelessWidget {
  const ExpenseLedgerSection({
    super.key,
    required this.expenses,
    required this.onTapExpense,
  });

  final List<Expense> expenses;
  final ValueChanged<Expense> onTapExpense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return ExpenseTable(expenses: expenses, onTapExpense: onTapExpense);
        }

        return Column(
          children: [
            for (var i = 0; i < expenses.length; i++) ...[
              ExpenseTile(
                expense: expenses[i],
                onTap: () => onTapExpense(expenses[i]),
              ),
              if (i != expenses.length - 1) const Divider(),
            ],
          ],
        );
      },
    );
  }
}
