import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

/// Cash in and out stay neutral here, unlike Finance's own ledger —
/// this card's job is reporting the period's totals, and the
/// comparison line below (closing cash vs last period) is this
/// screen's one red/green signal. Coloring the in/out figures too
/// would compete with it instead of reinforcing it.
class CashReportCard extends StatelessWidget {
  const CashReportCard({
    super.key,
    required this.cash,
    required this.comparisonLabel,
  });

  final CashReportSection cash;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Cash',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStat(
                  label: 'CASH IN',
                  value: formatNaira(cash.cashIn),
                ),
              ),
              Expanded(
                child: AppStat(
                  label: 'CASH OUT',
                  value: formatNaira(cash.cashOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppStat(
            label: 'CLOSING CASH IN HAND',
            value: formatNaira(cash.closingCash),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReportComparisonLine(
            current: cash.closingCash,
            previous: cash.previousClosingCash,
            comparisonLabel: comparisonLabel,
          ),
        ],
      ),
    );
  }
}
