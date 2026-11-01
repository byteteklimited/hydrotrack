import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A small labelled figure — caption above, tabular-figure value below,
/// optional trend/qualifier line beneath that. A building block meant to be
/// composed inside [AppCard], not a standalone hero widget.
class AppStat extends StatelessWidget {
  const AppStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.qualifier,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? qualifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.statLabel.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.moneyLarge.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
        if (qualifier != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            qualifier!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
