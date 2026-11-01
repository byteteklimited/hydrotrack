import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/providers/finance_providers.dart';

/// Today's money in versus money out — green and red, side by side.
class FinanceFlowCard extends StatelessWidget {
  const FinanceFlowCard({super.key, required this.totals});

  final FinanceTodayTotals totals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: AppStat(
              label: 'MONEY IN TODAY',
              value: formatNaira(totals.moneyInToday),
              valueColor: AppColors.moneyIn,
            ),
          ),
          Expanded(
            child: AppStat(
              label: 'MONEY OUT TODAY',
              value: formatNaira(totals.moneyOutToday),
              valueColor: AppColors.moneyOut,
            ),
          ),
        ],
      ),
    );
  }
}
