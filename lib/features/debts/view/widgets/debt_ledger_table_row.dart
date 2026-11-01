import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/ledger_entry.dart';

/// One row in the tablet/desktop ledger table: date, description, signed
/// amount, and running balance as aligned columns instead of
/// [DebtLedgerRow]'s stacked mobile layout. The running balance is
/// deliberately never red here — see [DebtLedgerTable]'s own doc
/// comment for why.
class DebtLedgerTableRow extends StatelessWidget {
  const DebtLedgerTableRow({
    super.key,
    required this.entry,
    required this.runningBalance,
    required this.tinted,
  });

  final LedgerEntry entry;
  final num runningBalance;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPayment = entry.type == LedgerEntryType.payment;
    final delta = entry.type.balanceDelta(entry.amount);
    final signedAmount =
        '${delta < 0 ? '-' : '+'}${formatNaira(entry.amount.abs())}';

    return Container(
      color: tinted ? AppColors.tableRowTint : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('d MMM yyyy').format(entry.date),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Text(
              entry.note ?? entry.type.defaultLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              signedAmount,
              textAlign: TextAlign.right,
              style: AppTypography.tabularBody.copyWith(
                color: isPayment
                    ? AppColors.moneyIn
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              formatNaira(runningBalance),
              textAlign: TextAlign.right,
              style: AppTypography.tabularBody.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
