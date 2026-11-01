import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/providers/organization_providers.dart';

enum _AccountAction { switchOrganization, signOut }

/// The signed-in person's avatar as an app-bar menu: which organization
/// they're in, "Switch organization" and "Sign out". Used on phones,
/// where there's no sidebar footer to hold these.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final organization = ref.watch(currentOrganizationProvider);
    if (user == null || organization == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      onSelected: (action) => switch (action) {
        _AccountAction.switchOrganization => switchOrganization(context, ref),
        _AccountAction.signOut => signOutAndReturnToLogin(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(organization.name, style: textTheme.titleSmall),
              Text(
                '${user.fullName} · ${user.role.label}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.switchOrganization,
          child: ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('Switch organization'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.cyanTint10,
          child: Text(
            user.initials,
            style: textTheme.labelMedium?.copyWith(color: AppColors.brandNavy),
          ),
        ),
      ),
    );
  }
}
