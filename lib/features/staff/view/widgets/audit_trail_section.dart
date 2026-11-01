import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../data/models/audit_entry.dart';
import 'audit_entry_row.dart';
import 'audit_entry_table.dart';

/// The audit trail — a stacked row per entry on phone ([AuditEntryRow]),
/// an [AuditEntryTable] with description/staff/when as columns from the
/// medium breakpoint up. Same mobile-vs-table switch established for
/// every other ledger/list this session. No `AppCard` here either way —
/// `audit_trail_screen.dart` already wraps everything in one card.
class AuditTrailSection extends StatelessWidget {
  const AuditTrailSection({super.key, required this.entries});

  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return AuditEntryTable(entries: entries);
        }

        return Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              AuditEntryRow(entry: entries[i]),
              if (i != entries.length - 1) const Divider(),
            ],
          ],
        );
      },
    );
  }
}
