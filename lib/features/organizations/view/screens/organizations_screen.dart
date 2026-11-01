import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../admin/data/providers/admin_providers.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/membership.dart';
import '../../data/providers/organization_providers.dart';
import '../widgets/membership_tile.dart';
import '../widgets/single_field_action_screen.dart';

/// Pick which organization to work in — and, for someone in none yet,
/// create one or join one with an invite code. Reached after sign-in when
/// there's a choice to make, and from "Switch organization".
class OrganizationsScreen extends ConsumerWidget {
  const OrganizationsScreen({super.key});

  static const _maxContentWidth = 680.0;

  Future<void> _openCreatedOrJoined(
    BuildContext context,
    WidgetRef ref,
    String? organizationId,
  ) async {
    if (organizationId == null) return;
    final memberships = await ref.refresh(myMembershipsProvider.future);
    final membership = memberships
        .where((m) => m.organization.id == organizationId && m.isActive)
        .firstOrNull;
    if (membership != null && context.mounted) {
      await openOrganization(context, ref, membership);
    }
  }

  Future<void> _createOrganization(BuildContext context, WidgetRef ref) async {
    final id = await showAppModal<String>(
      context,
      builder: (_) => SingleFieldActionScreen<String>(
        title: 'Create organization',
        fieldLabel: 'Business name',
        helperText: 'You can change this later',
        submitLabel: 'Create organization',
        emptyMessage: 'Enter your business name',
        onSubmit: (ref, name) async =>
            (await ref
                    .read(organizationActionControllerProvider.notifier)
                    .create(name))
                ?.id,
      ),
    );
    if (context.mounted) await _openCreatedOrJoined(context, ref, id);
  }

  Future<void> _joinOrganization(BuildContext context, WidgetRef ref) async {
    final id = await showAppModal<String>(
      context,
      builder: (_) => SingleFieldActionScreen<String>(
        title: 'Join with invite code',
        fieldLabel: 'Invite code',
        helperText:
            'The code must have been sent to the phone number or email you signed in with',
        submitLabel: 'Join organization',
        emptyMessage: 'Enter your invite code',
        onSubmit: (ref, code) => ref
            .read(organizationActionControllerProvider.notifier)
            .join(code.toUpperCase()),
      ),
    );
    if (context.mounted) await _openCreatedOrJoined(context, ref, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(myMembershipsProvider);
    final currentId = ref.watch(currentOrganizationProvider)?.id;

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Create organization',
          leadingIcon: Icons.add,
          onPressed: () => _createOrganization(context, ref),
          expanded: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Join with invite code',
          variant: AppButtonVariant.secondary,
          leadingIcon: Icons.vpn_key_outlined,
          onPressed: () => _joinOrganization(context, ref),
          expanded: true,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your organizations'),
        automaticallyImplyLeading: false,
        actions: [
          if (ref.watch(isPlatformAdminProvider).valueOrNull ?? false)
            IconButton(
              tooltip: 'HydroTrack admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.admin),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => signOutAndReturnToLogin(context, ref),
          ),
        ],
      ),
      body: membershipsAsync.when(
        loading: () => const AppLoading(),
        error: (_, _) => AppErrorState(
          message:
              "Couldn't load your organizations. Check your connection and try again.",
          onRetry: () => ref.invalidate(myMembershipsProvider),
        ),
        data: (memberships) => RefreshIndicator(
          onRefresh: () => ref.refresh(myMembershipsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ResponsiveCenter(
                maxWidth: _maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (memberships.isEmpty)
                      const AppEmptyState(
                        icon: Icons.business_outlined,
                        title: "You're not in an organization yet",
                        message:
                            'Create one for your factory, or join with the invite code your admin gave you.',
                      )
                    else
                      _MembershipList(
                        memberships: memberships,
                        currentId: currentId,
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    actions,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipList extends ConsumerWidget {
  const _MembershipList({required this.memberships, required this.currentId});

  final List<Membership> memberships;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      title: 'Choose where to work',
      child: Column(
        children: [
          for (var i = 0; i < memberships.length; i++) ...[
            MembershipTile(
              membership: memberships[i],
              isCurrent: memberships[i].organization.id == currentId,
              onTap: () => openOrganization(context, ref, memberships[i]),
            ),
            if (i != memberships.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
