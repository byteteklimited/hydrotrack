import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// Thin bar showing balance against credit limit — amber once at or
/// over the limit, same "threshold crossed" meaning as Inventory's
/// low-stock bars. Being over a credit limit isn't the same thing as
/// being overdue (that's this screen's one red signal, used on the
/// customer list and summary card) — a distributor can be comfortably
/// within their payment terms and still be over a limit that simply
/// needs reviewing, so this stays a warning, not a red flag.
class CreditLimitBar extends StatelessWidget {
  const CreditLimitBar({
    super.key,
    required this.balance,
    required this.creditLimit,
  });

  final num balance;
  final num creditLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = creditLimit > 0 && balance >= creditLimit;
    final fraction = creditLimit == 0
        ? 1.0
        : (balance / creditLimit).clamp(0.0, 1.0);
    final color = isOver
        ? AppColors.lowStockWarning
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: LinearProgressIndicator(
            value: fraction.toDouble(),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${formatNaira(balance)} of ${formatNaira(creditLimit)} limit',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
