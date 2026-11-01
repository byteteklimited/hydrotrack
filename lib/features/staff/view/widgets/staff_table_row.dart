import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/staff_member.dart';

/// One row in the tablet/desktop staff table: name (with the inactive
/// tag inline), phone, role, and join date as aligned columns instead
/// of [StaffTile]'s stacked mobile layout. The inactive tag is the only
/// color here — same rule as the mobile tile, nothing else borrows red.
class StaffTableRow extends StatelessWidget {
  const StaffTableRow({
    super.key,
    required this.staff,
    required this.tinted,
    required this.onTap,
  });

  final StaffMember staff;

  /// Alternating zebra-stripe background — on for odd rows, off for even.
  final bool tinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = !staff.isActive;

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
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      staff.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: dimmed
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  if (dimmed) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const AppStatusTag(
                      label: 'INACTIVE',
                      color: AppColors.moneyOut,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(staff.phone, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(staff.role.label, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('d MMM yyyy').format(staff.joinedOn),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
