import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/staff_member.dart';

/// One row in the staff roster: name, role, and phone — dimmed with an
/// "Inactive" tag once the account is deactivated.
class StaffTile extends StatelessWidget {
  const StaffTile({super.key, required this.staff, required this.onTap});

  final StaffMember staff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = !staff.isActive;

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
                  Row(
                    children: [
                      Text(
                        staff.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: dimmed
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    staff.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              staff.role.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
