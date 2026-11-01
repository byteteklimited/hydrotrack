import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../data/models/finance_position.dart';

/// The business's running position: cash in hand and the bank/transfer
/// balance, side by side.
class FinancePositionCard extends StatelessWidget {
  const FinancePositionCard({super.key, required this.position});

  final FinancePosition position;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: AppStat(
              label: 'CASH IN HAND',
              value: formatNaira(position.cashInHand),
            ),
          ),
          Expanded(
            child: AppStat(
              label: 'BANK / TRANSFER BALANCE',
              value: formatNaira(position.bankBalance),
            ),
          ),
        ],
      ),
    );
  }
}
