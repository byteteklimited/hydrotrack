import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

/// Unlike Debts' own list (which leads with red for an overdue
/// customer), this card reports a period total — it's never red just
/// because money is outside, only the comparison line below (closing
/// vs last period, `higherIsBetter: false` since less owed is the good
/// direction) carries that signal here.
class MoneyOutsideReportCard extends StatelessWidget {
  const MoneyOutsideReportCard({
    super.key,
    required this.moneyOutside,
    required this.comparisonLabel,
  });

  final MoneyOutsideReportSection moneyOutside;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Money outside',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStat(
                  label: 'OPENING',
                  value: formatNaira(moneyOutside.opening),
                ),
              ),
              Expanded(
                child: AppStat(
                  label: 'CLOSING',
                  value: formatNaira(moneyOutside.closing),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: moneyOutside.closing,
            previous: moneyOutside.previousClosing,
            comparisonLabel: comparisonLabel,
            higherIsBetter: false,
          ),
        ],
      ),
    );
  }
}
