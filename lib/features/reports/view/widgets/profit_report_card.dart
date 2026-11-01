import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

/// The answer first: profit, with the revenue-minus-expenses formula
/// shown plainly rather than hidden behind a single number. Whether
/// profit is up or down from last period is what the comparison line
/// below is for — the headline figure itself stays neutral, same as
/// every other report card here, so that line is the one thing on this
/// screen that reads as red/green.
class ProfitReportCard extends StatelessWidget {
  const ProfitReportCard({
    super.key,
    required this.profit,
    required this.comparisonLabel,
  });

  final ProfitReportSection profit;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      title: 'Profit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatNaira(profit.profit), style: AppTypography.moneyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Revenue ${formatNaira(profit.revenue)} − Cost of bags sold '
            '${formatNaira(profit.costOfSales)} − Expenses '
            '${formatNaira(profit.expenses)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: profit.profit,
            previous: profit.previousProfit,
            comparisonLabel: comparisonLabel,
          ),
        ],
      ),
    );
  }
}
