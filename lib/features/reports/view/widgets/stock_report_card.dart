import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

class StockReportCard extends StatelessWidget {
  const StockReportCard({
    super.key,
    required this.stock,
    required this.comparisonLabel,
  });

  final StockReportSection stock;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      title: 'Stock',
      accentColor: stock.lowItems.isEmpty ? null : AppColors.lowStockWarning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stock.lowItems.isEmpty)
            Text(
              'No finished goods running low.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final item in stock.lowItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  '${item.name} — ${item.quantityRemaining} ${item.unit} left',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: stock.lowItems.length,
            previous: stock.previousLowItemCount,
            comparisonLabel: comparisonLabel,
            higherIsBetter: false,
            formatValue: (value) =>
                '${value.round()} ${value.round() == 1 ? 'item' : 'items'}',
          ),
        ],
      ),
    );
  }
}
