import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/ledger_entry.dart';

/// One ledger row: what happened, when, the signed amount, and the
/// running balance after it — in tabular figures so the column aligns.
/// The running balance is never colored red here, even when positive —
/// an outstanding balance partway through routine, expected credit
/// history isn't "overdue," and painting every row red once it ticked
/// above zero competed with the one place on this screen red actually
/// means something (a customer being overdue, on the summary card and
/// the customer list).
class DebtLedgerRow extends StatelessWidget {
  const DebtLedgerRow({
    super.key,
    required this.entry,
    required this.runningBalance,
  });

  final LedgerEntry entry;
  final num runningBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPayment = entry.type == LedgerEntryType.payment;
    final delta = entry.type.balanceDelta(entry.amount);
    final signedAmount =
        '${delta < 0 ? '-' : '+'}${formatNaira(entry.amount.abs())}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.note ?? entry.type.defaultLabel,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat('d MMM yyyy').format(entry.date),
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
                signedAmount,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPayment ? AppColors.moneyIn : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatNaira(runningBalance),
                style: AppTypography.tabularBody.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
