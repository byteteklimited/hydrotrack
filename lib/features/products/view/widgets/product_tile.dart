import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/product.dart';

/// One product: name, unit, its two prices, and whether it's retired.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.costToMake = 0,
  });

  final Product product;
  final VoidCallback onTap;

  /// Average material cost per unit (0 until costs are known).
  final num costToMake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: product.isRetired ? AppColors.textSecondary : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Walk-in ${formatNaira(product.walkInPrice)} · '
                    'Distributor ${formatNaira(product.distributorPrice)} · '
                    'sold in ${product.unit}'
                    '${costToMake > 0 ? ' · costs ${formatNairaWithKobo(costToMake)} to make' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (product.isRetired)
              const AppStatusTag(
                label: 'Retired',
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
