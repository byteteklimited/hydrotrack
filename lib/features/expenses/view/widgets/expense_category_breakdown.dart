import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/expense.dart';

/// Compact bar-per-category breakdown, largest first, sized relative to
/// the biggest category — so whatever's eating the budget (usually
/// diesel) is immediately obvious.
class ExpenseCategoryBreakdown extends StatelessWidget {
  const ExpenseCategoryBreakdown({super.key, required this.byCategory});

  final Map<ExpenseCategory, num> byCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAmount = byCategory.values.isEmpty
        ? 1
        : byCategory.values.reduce((a, b) => a > b ? a : b);

    return AppCard(
      title: 'By category',
      child: Column(
        children: [
          for (final entry in byCategory.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key.label, style: theme.textTheme.bodyMedium),
                      Text(
                        formatNaira(entry.value),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: LinearProgressIndicator(
                      value: entry.value / maxAmount,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
