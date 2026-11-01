import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../subscriptions/view/widgets/subscription_status_tag.dart';
import '../../data/models/admin_organization.dart';

/// One organization in the admin console list.
class AdminOrganizationTile extends StatelessWidget {
  const AdminOrganizationTile({
    super.key,
    required this.organization,
    required this.onTap,
  });

  final AdminOrganization organization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = organization.subscription;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        title: organization.name,
        trailing: subscription == null
            ? null
            : SubscriptionStatusTag(status: subscription.status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                organization.ownerName ?? 'No owner',
                ?organization.ownerPhone ?? organization.ownerEmail,
                '${organization.staffCount} staff',
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            if (subscription != null)
              Text(
                subscriptionSummary(subscription, DateTime.now()),
                style: secondary,
              ),
            Text(
              organization.lastActivityAt == null
                  ? 'No activity yet'
                  : 'Last activity '
                        '${formatSubscriptionDate(organization.lastActivityAt!)}',
              style: secondary,
            ),
          ],
        ),
      ),
    );
  }
}
