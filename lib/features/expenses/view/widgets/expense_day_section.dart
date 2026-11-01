import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/expense.dart';
import 'expense_ledger_section.dart';

/// One day's expenses, grouped under a relative date header — a stacked
/// card per entry on phone, a real table from the medium breakpoint up.
class ExpenseDaySection extends StatelessWidget {
  const ExpenseDaySection({
    super.key,
    required this.date,
    required this.expenses,
    required this.onExpenseTap,
  });

  final DateTime date;
  final List<Expense> expenses;
  final ValueChanged<Expense> onExpenseTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: formatRelativeDay(date),
      child: ExpenseLedgerSection(
        expenses: expenses,
        onTapExpense: onExpenseTap,
      ),
    );
  }
}
