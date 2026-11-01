import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/driver.dart';
import '../../data/models/load_out.dart';
import '../../data/models/vehicle.dart';

/// One settled trip's summary row: who, what vehicle, sold/returned/
/// damaged, and cash banked. Flags a discrepancy note if there is one.
class SettledLoadOutTile extends StatelessWidget {
  const SettledLoadOutTile({
    super.key,
    required this.loadOut,
    required this.driver,
    required this.vehicle,
  });

  final LoadOut loadOut;
  final Driver driver;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscrepancy = loadOut.discrepancyNote != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${driver.name} · ${vehicle.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatNaira(loadOut.cashReturned ?? 0),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${loadOut.bagsSold} sold · ${loadOut.bagsReturned} returned · ${loadOut.bagsDamaged} damaged',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasDiscrepancy) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              loadOut.discrepancyNote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.moneyOut,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
