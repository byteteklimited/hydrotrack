import 'package:flutter/material.dart';

import '../../../../core/constants/production_thresholds.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../offline/view/widgets/needs_checking_tag.dart';
import '../../data/models/production_run.dart';

/// One row within a day's group: shift + machine, operator, and the
/// quantity/wastage figures. Tap to see the full record.
class ProductionRunTile extends StatelessWidget {
  const ProductionRunTile({super.key, required this.run, required this.onTap});

  final ProductionRun run;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Icon(
                Icons.factory_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${run.shift.label} · ${run.machine}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${run.operatorName} · ${run.product.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${run.quantityProduced} bags',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${run.wastage} wasted',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        wastageColor(run.wastagePercent) ??
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                NeedsCheckingTag(productionRunId: run.id),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
