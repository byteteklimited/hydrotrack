import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/cash_entry.dart';

/// One row in the tablet/desktop ledger table: time, description,
/// method, and the signed amount as aligned columns instead of
/// [CashEntryTile]'s stacked mobile layout. Amount color stays tied
/// strictly to direction (green in, red out) — never to source/
/// category, same rule the mobile tile already followed.
class CashEntryTableRow extends StatelessWidget {
  const CashEntryTableRow({
    super.key,
    required this.entry,
    required this.tinted,
    required this.onTap,
  });

  final CashEntry entry;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = entry.direction == CashDirection.moneyOut;
    final signedText = '${isOut ? '-' : '+'}${formatNaira(entry.amount)}';

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
              flex: 1,
              child: Text(
                DateFormat.jm().format(entry.dateTime),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Text(
                entry.note ?? entry.source.label,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(entry.method.label, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                signedText,
                textAlign: TextAlign.right,
                style: AppTypography.tabularBody.copyWith(
                  color: isOut ? AppColors.moneyOut : AppColors.moneyIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
