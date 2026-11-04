import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/models/organization.dart';
import '../screens/business_profile_screen.dart';
import 'logo_upload_buttons.dart';
import 'organization_logo.dart';

/// Organization settings: logo, business name and profile as they appear
/// on receipts and reports, with Edit and logo upload.
class BusinessProfileCard extends ConsumerWidget {
  const BusinessProfileCard({super.key, required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lines = organization.profile.headerLines;

    return AppCard(
      title: 'Business profile',
      trailing: AppButton(
        label: 'Edit',
        variant: AppButtonVariant.text,
        onPressed: () => showAppModal<void>(
          context,
          builder: (_) => BusinessProfileScreen(organization: organization),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const OrganizationLogo(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  organization.name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in lines)
            Text(line, style: theme.textTheme.bodyMedium),
          if (lines.isEmpty)
            Text(
              'Add your address, phone and registration numbers: they print '
              'under your name on receipts and reports.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          LogoUploadButtons(organization: organization),
        ],
      ),
    );
  }
}
