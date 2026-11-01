import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/expense.dart';

/// One row in the tablet/desktop expense table: category icon +
/// description, category, method, and amount as aligned columns instead
/// of [ExpenseTile]'s stacked mobile layout. Amount is plain tabular
/// text, no color — this screen tracks running costs, not a direction
/// or a threshold, so nothing here is red/amber/green.
class ExpenseTableRow extends StatelessWidget {
  const ExpenseTableRow({
    super.key,
    required this.expense,
    required this.tinted,
    required this.onTap,
  });

  final Expense expense;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: tinted ? AppColors.tableRowTint : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(
                    expense.category.icon,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      expense.description,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                expense.category.label,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                expense.method.label,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                formatNaira(expense.amount),
                textAlign: TextAlign.right,
                style: AppTypography.tabularBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
