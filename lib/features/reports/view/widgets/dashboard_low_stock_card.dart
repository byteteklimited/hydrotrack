import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/dashboard_snapshot.dart';

/// Low-stock strip. The dashboard only shows this when [alert] is non-null
/// — absent when nothing is low.
class DashboardLowStockCard extends StatelessWidget {
  const DashboardLowStockCard({super.key, required this.alert});

  final LowStockAlert alert;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: AppColors.lowStockWarning,
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_outlined,
            color: AppColors.lowStockWarning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${alert.materialName} — ${alert.quantityRemaining} ${alert.unit} left. '
              'Reorder soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
