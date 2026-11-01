import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/ledger_entry.dart';
import 'debt_ledger_table_row.dart';

class _DebtLedgerTableHeader extends StatelessWidget {
  const _DebtLedgerTableHeader();

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
          Expanded(flex: 2, child: Text('DATE', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 4, child: Text('DESCRIPTION', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('AMOUNT', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('BALANCE', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of a customer's ledger — date,
/// description, signed amount, and running balance as aligned columns,
/// zebra-striped with the app's reserved `tableRowTint` so a long ledger
/// stays easy to scan a row at a time.
///
/// The running balance is intentionally never red here, unlike earlier
/// in this feature's history. This screen already leads with red for
/// one specific thing — a customer being overdue, on the summary card
/// and the customer list — and every row of a routine, fully-expected
/// credit ledger showing red the moment the balance ticked above zero
/// was competing with that signal, not reinforcing it. A positive
/// running balance here is normal business, not a problem.
class DebtLedgerTable extends StatelessWidget {
  const DebtLedgerTable({super.key, required this.entries});

  final List<(LedgerEntry, num)> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const _DebtLedgerTableHeader(),
          const Divider(height: 1),
          for (var i = 0; i < entries.length; i++)
            DebtLedgerTableRow(
              entry: entries[i].$1,
              runningBalance: entries[i].$2,
              tinted: i.isOdd,
            ),
        ],
      ),
    );
  }
}
