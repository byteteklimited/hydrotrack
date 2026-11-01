import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/cash_entry.dart';
import 'cash_entry_table_row.dart';

class _CashEntryTableHeader extends StatelessWidget {
  const _CashEntryTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('TIME', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 3, child: Text('DESCRIPTION', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('METHOD', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('AMOUNT', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of the cash ledger — time, description,
/// method, and signed amount as aligned columns, zebra-striped with the
/// app's reserved `tableRowTint` so a busy day's ledger stays easy to
/// scan a row at a time. Same `AppCard` surface and striping treatment
/// as Debts' own ledger table.
class CashEntryTable extends StatelessWidget {
  const CashEntryTable({
    super.key,
    required this.entries,
    required this.onTapEntry,
  });

  final List<CashEntry> entries;
  final ValueChanged<CashEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const _CashEntryTableHeader(),
          const Divider(height: 1),
          for (var i = 0; i < entries.length; i++)
            CashEntryTableRow(
              entry: entries[i],
              tinted: i.isOdd,
              onTap: () => onTapEntry(entries[i]),
            ),
        ],
      ),
    );
  }
}
