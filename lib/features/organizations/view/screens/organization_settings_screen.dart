import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../offline/view/widgets/offline_device_card.dart';
import '../../../offline/view/widgets/registered_devices_card.dart';
import '../../../subscriptions/view/widgets/subscription_card.dart';
import '../../data/providers/organization_providers.dart';
import '../widgets/business_profile_card.dart';
import '../widgets/debt_reminders_card.dart';

/// Organization settings (Owner/Admin): the subscription, the business
/// profile receipts and reports carry, the bank details SMS debt
/// reminders print, offline use on this device, and switching to another
/// organization. Staff and invite codes are managed on the Staff screen.
class OrganizationSettingsScreen extends ConsumerWidget {
  const OrganizationSettingsScreen({super.key});

  static const _maxContentWidth = 720.0;

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
                const SubscriptionCard(),
                BusinessProfileCard(organization: organization),
                const SizedBox(height: AppSpacing.lg),
                DebtRemindersCard(organization: organization),
                const SizedBox(height: AppSpacing.lg),
                OfflineDeviceCard(organization: organization),
                const RegisteredDevicesCard(),
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
