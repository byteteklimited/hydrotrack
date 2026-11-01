import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../subscriptions/view/widgets/subscription_status_tag.dart';
import '../../data/models/admin_organization.dart';

/// Who to contact and how active the organization is.
class AdminOrganizationDetailsCard extends StatelessWidget {
  const AdminOrganizationDetailsCard({super.key, required this.organization});

  final AdminOrganization organization;

  @override
  Widget build(BuildContext context) {
    final lastActivity = organization.lastActivityAt;
    return AppCard(
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(label: 'Owner', value: organization.ownerName ?? 'No owner'),
          _Row(label: 'Owner phone', value: organization.ownerPhone ?? '—'),
          _Row(label: 'Owner email', value: organization.ownerEmail ?? '—'),
          _Row(
            label: 'Business phone',
            value: organization.businessPhone ?? '—',
          ),
          _Row(label: 'Active staff', value: '${organization.staffCount}'),
          _Row(
            label: 'Created',
            value: formatSubscriptionDate(organization.createdAt),
          ),
          _Row(
            label: 'Last activity',
            value: lastActivity == null
                ? 'None yet'
                : formatSubscriptionDate(lastActivity),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
