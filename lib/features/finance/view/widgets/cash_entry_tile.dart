import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/cash_entry.dart';

/// One ledger row: time, what it was for in plain words, and the signed
/// amount in tabular figures — red when money went out.
class CashEntryTile extends StatelessWidget {
  const CashEntryTile({super.key, required this.entry, required this.onTap});

  final CashEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = entry.direction == CashDirection.moneyOut;
    final signedText = '${isOut ? '-' : '+'}${formatNaira(entry.amount)}';

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
                    entry.note ?? entry.source.label,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat.jm().format(entry.dateTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              signedText,
              style: AppTypography.tabularBody.copyWith(
                color: isOut ? AppColors.moneyOut : AppColors.moneyIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
