import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/powered_by.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../widgets/change_secret_card.dart';
import '../widgets/profile_card.dart';
import '../widgets/settings_links_card.dart';

/// Settings, for everyone: their name, their PIN or password, and (for
/// Owners/Admins) the way to organization settings and the plan.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _maxContentWidth = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const SizedBox.shrink();
    final email = ref.watch(authRepositoryProvider).signInEmail;
    // Email accounts sign in with a password; phone accounts with a PIN.
    final identifier = email ?? user.phone;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileCard(user: user, signInWith: identifier),
                const SizedBox(height: AppSpacing.lg),
                ChangeSecretCard(
                  identifier: identifier,
                  usesPassword: email != null,
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsLinksCard(user: user),
                const SizedBox(height: AppSpacing.lg),
                const PoweredBy(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
