import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/stock_movement.dart';

/// One row in an item's movement ledger — what happened, the signed
/// quantity, who did it, and when.
class StockMovementTile extends StatelessWidget {
  const StockMovementTile({
    super.key,
    required this.movement,
    required this.unit,
  });

  final StockMovement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncrease = movement.quantity >= 0;
    final color = isIncrease ? AppColors.moneyIn : AppColors.moneyOut;
    final sign = isIncrease ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            movement.type.icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.note ?? movement.type.label,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${movement.byWhom} · ${DateFormat.yMMMd().add_jm().format(movement.at)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign${movement.quantity} $unit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
