import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../data/models/membership.dart';
import 'organization_logo.dart';

/// One organization on the picker: name, your role there, and a
/// "Deactivated" tag (not tappable) when an admin has switched your access
/// off.
class MembershipTile extends StatelessWidget {
  const MembershipTile({
    super.key,
    required this.membership,
    required this.isCurrent,
    required this.onTap,
  });

  final Membership membership;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = membership.isActive;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            OrganizationBadge(
              organization: membership.organization,
              enabled: enabled,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership.organization.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: enabled ? null : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCurrent
                        ? '${membership.role.label} · Open now'
                        : membership.role.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary)
            else
              const AppStatusTag(
                label: 'Deactivated',
                color: AppColors.moneyOut,
              ),
          ],
        ),
      ),
    );
  }
}
