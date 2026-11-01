import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/expense.dart';

/// Same reasoning as every other detail screen in the app: content
/// reads best at a bounded width, implemented as responsive padding so
/// `ListView` keeps its native scroll behavior.
const double _contentCap = 720;

/// Full record of one expense, including who recorded it.
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(expense.description)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatNaira(expense.amount),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'Category',
                      value: expense.category.label,
                    ),
                    _DetailRow(
                      label: 'Description',
                      value: expense.description,
                    ),
                    _DetailRow(label: 'Method', value: expense.method.label),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat.yMMMd().format(expense.date),
                    ),
                    _DetailRow(label: 'Recorded by', value: expense.recordedBy),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
