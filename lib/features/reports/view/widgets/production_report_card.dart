import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

class ProductionReportCard extends StatelessWidget {
  const ProductionReportCard({
    super.key,
    required this.production,
    required this.comparisonLabel,
  });

  final ProductionReportSection production;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Production',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStat(
                  label: 'BAGS PRODUCED',
                  value: '${production.bagsProduced}',
                ),
              ),
              Expanded(
                child: AppStat(
                  label: 'WASTAGE',
                  value: '${production.wastage} bags',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: production.bagsProduced,
            previous: production.previousBagsProduced,
            comparisonLabel: comparisonLabel,
            formatValue: (value) =>
                '${value.round()} ${value.round() == 1 ? 'bag' : 'bags'}',
          ),
        ],
      ),
    );
  }
}
