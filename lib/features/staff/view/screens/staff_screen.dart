import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../organizations/data/models/invitation.dart';
import '../../data/models/staff_member.dart';
import '../../data/providers/staff_providers.dart';
import '../widgets/invite_code_dialog.dart';
import '../widgets/pending_invites_card.dart';
import '../widgets/staff_roster_section.dart';
import 'invite_staff_screen.dart';
import 'audit_trail_screen.dart';
import 'staff_detail_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// The current organization's team — who's a member, their role here,
/// and whether their access is active — plus invite codes still waiting
/// to be used. Owners/Admins invite and manage; Managers can view.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final isAdmin = ref.watch(authStateProvider)?.role.isAdminLevel ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Audit trail',
            onPressed: () =>
                showAppModal(context, builder: (_) => const AuditTrailScreen()),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? AppButton(
              label: 'Invite staff',
              leadingIcon: Icons.person_add_outlined,
              onPressed: () async {
                final invitation = await showAppModal<Invitation>(
                  context,
                  builder: (_) => const InviteStaffScreen(),
                );
                if (invitation == null || !context.mounted) return;
                await showInviteCodeDialog(context, invitation);
              },
            )
          : null,
      body: staffAsync.when(
        data: (staff) => _StaffBody(staff: staff, isAdmin: isAdmin),
        loading: () => const AppLoading(message: 'Loading staff roster…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load the staff roster. Check your connection and try again.",
          onRetry: () => ref.invalidate(staffProvider),
        ),
      ),
    );
  }
}

class _StaffBody extends ConsumerWidget {
  const _StaffBody({required this.staff, required this.isAdmin});

  final List<StaffMember> staff;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = staff.where((s) => s.isActive).toList();
    final inactive = staff.where((s) => !s.isActive).toList();

    Future<void> openStaff(StaffMember member) async {
      final removed = await showAppModal<bool>(
        context,
        builder: (_) => StaffDetailScreen(staffId: member.id),
      );
      if (removed == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.fullName} was removed from this organization.',
            ),
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > _contentCap
            ? (constraints.maxWidth - _contentCap) / 2
            : AppSpacing.lg;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(invitationsProvider);
            ref.invalidate(staffProvider);
            await ref.read(staffProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            children: [
              if (isAdmin) const PendingInvitesCard(),
              AppCard(
                child: StaffRosterSection(staff: active, onTap: openStaff),
              ),
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: ExpansionTile(
                    title: Text(
                      'Inactive (${inactive.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      StaffRosterSection(staff: inactive, onTap: openStaff),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
