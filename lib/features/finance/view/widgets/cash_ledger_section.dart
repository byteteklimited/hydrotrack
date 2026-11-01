import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/cash_entry.dart';
import 'cash_entry_table.dart';
import 'cash_entry_tile.dart';

/// The cash ledger — a stacked card per entry on phone
/// ([CashEntryTile]), a [CashEntryTable] with time/description/method/
/// amount as columns from the medium breakpoint up. Same entries either
/// way, same mobile-vs-table switch `DebtLedgerSection`/
/// `SaleLinesSection` already established for their own ledgers/tables.
class CashLedgerSection extends StatelessWidget {
  const CashLedgerSection({
    super.key,
    required this.entries,
    required this.onTapEntry,
  });

  final List<CashEntry> entries;
  final ValueChanged<CashEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return CashEntryTable(entries: entries, onTapEntry: onTapEntry);
        }

        return AppCard(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                CashEntryTile(
                  entry: entries[i],
                  onTap: () => onTapEntry(entries[i]),
                ),
                if (i != entries.length - 1) const Divider(),
              ],
            ],
          ),
        );
      },
    );
  }
}
