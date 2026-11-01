import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../sales/data/models/sale.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

class SalesReportCard extends StatelessWidget {
  const SalesReportCard({
    super.key,
    required this.sales,
    required this.comparisonLabel,
  });

  final SalesReportSection sales;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      title: 'Sales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStat(label: 'BAGS SOLD', value: '${sales.bagsSold}'),
              ),
              Expanded(
                child: AppStat(
                  label: 'REVENUE',
                  value: formatNaira(sales.revenue),
                ),
              ),
            ],
          ),
          if (sales.revenueByMethod.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              sales.revenueByMethod.entries
                  .map(
                    (entry) => '${entry.key.label} ${formatNaira(entry.value)}',
                  )
                  .join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: sales.revenue,
            previous: sales.previousRevenue,
            comparisonLabel: comparisonLabel,
          ),
        ],
      ),
    );
  }
}
