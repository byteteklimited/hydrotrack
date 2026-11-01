import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';
import '../widgets/debt_reminders_card.dart';
import '../widgets/single_field_action_screen.dart';

/// Organization settings (Owner/Admin): the business name every receipt
/// and report carries, the bank details SMS debt reminders print, and
/// switching to another organization. Staff and
/// invite codes are managed on the Staff screen.
class OrganizationSettingsScreen extends ConsumerWidget {
  const OrganizationSettingsScreen({super.key});

  static const _maxContentWidth = 720.0;

  Future<void> _rename(BuildContext context, Organization organization) async {
    final renamed = await showAppModal<Organization>(
      context,
      builder: (_) => SingleFieldActionScreen<Organization>(
        title: 'Rename organization',
        fieldLabel: 'Business name',
        initialValue: organization.name,
        submitLabel: 'Save name',
        emptyMessage: 'Enter your business name',
        onSubmit: (ref, name) => ref
            .read(organizationActionControllerProvider.notifier)
            .rename(organizationId: organization.id, name: name),
      ),
    );
    if (renamed != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Organization renamed to ${renamed.name}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final user = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    if (organization == null || user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Organization')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  title: 'Business name',
                  trailing: AppButton(
                    label: 'Rename',
                    variant: AppButtonVariant.text,
                    onPressed: () => _rename(context, organization),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Shown on receipts, report exports and to everyone in this organization.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DebtRemindersCard(organization: organization),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  title: 'Your access',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "You're signed in as ${user.fullName} (${user.role.label}).",
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Switch organization',
                        variant: AppButtonVariant.secondary,
                        leadingIcon: Icons.swap_horiz,
                        onPressed: () => switchOrganization(context, ref),
                      ),
                    ],
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
