import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../data/models/audit_entry.dart';

/// One line in the audit trail: who did what, and when.
class AuditEntryRow extends StatelessWidget {
  const AuditEntryRow({super.key, required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.category.icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.staffName} (${entry.role.label}) · '
                  '${DateFormat('d MMM, h:mm a').format(entry.timestamp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
