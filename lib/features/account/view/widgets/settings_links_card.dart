import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../admin/data/providers/admin_providers.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../organizations/view/screens/organization_settings_screen.dart';
import '../../../subscriptions/view/screens/subscription_screen.dart';

/// Where to go from Settings: the organization's own settings and plan
/// (Owner/Admin), then switching organization and signing out.
class SettingsLinksCard extends ConsumerWidget {
  const SettingsLinksCard({super.key, required this.user});

  final StaffUser user;

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final isPlatformAdmin =
        ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
    final manages = user.role.isAdminLevel;

    return AppCard(
      title: organization?.name ?? 'Organization',
      child: Column(
        children: [
          if (manages) ...[
            _Link(
              icon: Icons.business_outlined,
              title: 'Organization settings',
              subtitle:
                  'Business profile, branding, bank details, locations, '
                  'devices',
              onTap: () => _push(context, const OrganizationSettingsScreen()),
            ),
            _Link(
              icon: Icons.workspace_premium_outlined,
              title: 'Plan and subscription',
              subtitle: 'Your plan, other plans and how to pay',
              onTap: () => _push(context, const SubscriptionScreen()),
            ),
          ],
          if (isPlatformAdmin)
            _Link(
              icon: Icons.admin_panel_settings_outlined,
              title: 'HydroTrack admin',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.admin),
            ),
          _Link(
            icon: Icons.swap_horiz,
            title: 'Switch organization',
            onTap: () => switchOrganization(context, ref),
          ),
          _Link(
            icon: Icons.logout,
            title: 'Sign out',
            onTap: () => signOutAndReturnToLogin(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
