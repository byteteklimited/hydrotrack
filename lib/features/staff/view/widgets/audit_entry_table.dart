import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/audit_entry.dart';
import 'audit_entry_table_row.dart';

class _AuditEntryTableHeader extends StatelessWidget {
  const _AuditEntryTableHeader();

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
          const SizedBox(width: 32),
          Expanded(flex: 4, child: Text('DESCRIPTION', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('STAFF', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('WHEN', style: style)),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of the audit trail — category icon,
/// description, staff, and when, as aligned columns, zebra-striped with
/// the app's reserved `tableRowTint`. No outer `AppCard` on purpose —
/// `audit_trail_screen.dart` already wraps everything in one card; this
/// is only ever used as that card's child.
class AuditEntryTable extends StatelessWidget {
  const AuditEntryTable({super.key, required this.entries});

  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AuditEntryTableHeader(),
        const Divider(height: 1),
        for (var i = 0; i < entries.length; i++)
          AuditEntryTableRow(entry: entries[i], tinted: i.isOdd),
      ],
    );
  }
}
