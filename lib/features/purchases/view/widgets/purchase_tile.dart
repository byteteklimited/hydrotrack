import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/purchase.dart';

/// One purchase: supplier, date, what was bought, total and what's owed.
class PurchaseTile extends StatelessWidget {
  const PurchaseTile({super.key, required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = purchase.lines
        .map(
          (l) =>
              '${l.quantity} ${l.unit} ${l.itemName} @ ${formatNaira(l.unitCost)}',
        )
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchase.supplierName,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${DateFormat('d MMM').format(purchase.date)} · $items',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatNaira(purchase.total),
                  style: theme.textTheme.titleSmall,
                ),
                if (purchase.owed > 0)
                  AppStatusTag(
                    label: 'Owed ${formatNaira(purchase.owed)}',
                    color: AppColors.lowStockWarning,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
