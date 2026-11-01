import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/customer.dart';

/// One row in the tablet/desktop customers table: name, phone, balance
/// (right-aligned, tabular), last payment date, and an aging chip —
/// same fields [DebtCustomerTile] shows, as aligned columns instead of
/// a stacked card.
class DebtCustomerTableRow extends StatelessWidget {
  const DebtCustomerTableRow({
    super.key,
    required this.customer,
    required this.onTap,
    required this.tinted,
  });

  final Customer customer;
  final VoidCallback onTap;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = customer.isOverdue;
    final inCredit = customer.isInCredit;
    final lastPayment = customer.lastPaymentDate;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: tinted ? AppColors.tableRowTint : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                customer.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                customer.phone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                inCredit
                    ? '${formatNaira(-customer.balance)} credit'
                    : formatNaira(customer.balance),
                textAlign: TextAlign.right,
                style: AppTypography.tabularBody.copyWith(
                  color: overdue ? AppColors.moneyOut : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                lastPayment == null
                    ? '—'
                    : DateFormat('d MMM').format(lastPayment),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 96,
              child: Align(
                alignment: Alignment.centerRight,
                child: AppStatusTag(
                  label: overdue
                      ? (lastPayment == null
                            ? 'Overdue'
                            : 'Overdue ${DateTime.now().difference(lastPayment).inDays}d')
                      : 'Current',
                  color: overdue ? AppColors.moneyOut : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
