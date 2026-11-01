import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/ledger_entry.dart';
import 'debt_ledger_row.dart';
import 'debt_ledger_table.dart';

/// A customer's ledger — a stacked card per entry on phone
/// ([DebtLedgerRow]), a [DebtLedgerTable] with date/description/amount/
/// balance as columns from the medium breakpoint up. Same entries
/// either way, just laid out differently once there's room for a real
/// table.
class DebtLedgerSection extends StatelessWidget {
  const DebtLedgerSection({super.key, required this.entries});

  final List<(LedgerEntry, num)> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return DebtLedgerTable(entries: entries);
        }

        return AppCard(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                DebtLedgerRow(
                  entry: entries[i].$1,
                  runningBalance: entries[i].$2,
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
