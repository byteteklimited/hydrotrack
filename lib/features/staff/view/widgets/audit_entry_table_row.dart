import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../data/models/audit_entry.dart';

/// One row in the tablet/desktop audit trail table: category icon,
/// description, who (name + role), and when — as aligned columns
/// instead of [AuditEntryRow]'s stacked mobile layout. Plain neutral
/// text throughout, same as the mobile row — nothing here is red,
/// amber, or green; the audit trail has no threshold or direction to
/// signal.
class AuditEntryTableRow extends StatelessWidget {
  const AuditEntryTableRow({
    super.key,
    required this.entry,
    required this.tinted,
  });

  final AuditEntry entry;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: tinted ? AppColors.tableRowTint : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Icon(
              entry.category.icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(entry.description, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              '${entry.staffName} · ${entry.role.label}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('d MMM, h:mm a').format(entry.timestamp),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
