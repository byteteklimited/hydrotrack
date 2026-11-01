import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/sale.dart';
import 'sale_payment_status_badge.dart';

/// One row in the sales list: time, customer, quantity, total, and a
/// payment-status badge — or, once voided, a dimmed strikethrough total
/// and a "VOIDED" tag in its place, since payment status no longer
/// means anything for a sale that's been reversed.
class SaleListTile extends StatelessWidget {
  const SaleListTile({super.key, required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = sale.isVoided ? theme.colorScheme.onSurfaceVariant : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.customerName ?? 'Walk-in',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${DateFormat.jm().format(sale.dateTime)} · ${sale.totalBags} bags',
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
                  formatNaira(sale.total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted,
                    decoration: sale.isVoided
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                sale.isVoided
                    ? const AppStatusTag(
                        label: 'Voided',
                        color: AppColors.moneyOut,
                      )
                    : SalePaymentStatusBadge(sale: sale),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
