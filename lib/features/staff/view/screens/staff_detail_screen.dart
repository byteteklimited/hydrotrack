import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/staff_member.dart';
import '../../data/providers/staff_providers.dart';
import '../widgets/reset_pin_button.dart';

/// Same reasoning as every other detail screen in the app: content
/// reads best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 720;

/// One member's details, with Owner/Admin actions: change role,
/// deactivate/reactivate their access, remove them from the organization.
class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return staffAsync.when(
      data: (staff) {
        // Null for a split second after "Remove", while the roster
        // refreshes and this modal closes.
        final member = staff.where((s) => s.id == staffId).firstOrNull;
        if (member == null) return const Scaffold(body: SizedBox.shrink());
        return _StaffDetailBody(staff: member);
      },
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              "Couldn't load this staff member. Check your connection and try again.",
          onRetry: () => ref.invalidate(staffProvider),
        ),
      ),
    );
  }
}

class _StaffDetailBody extends ConsumerWidget {
  const _StaffDetailBody({required this.staff});

  final StaffMember staff;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final updated = await ref
        .read(staffActionControllerProvider.notifier)
        .setActive(staffId: staff.id, isActive: !staff.isActive);
    if (!context.mounted) return;

    if (updated == null) {
      final error = ref.read(staffActionControllerProvider).error;
      showActionErrorSnackBar(context, message: readableErrorMessage(error));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isActive
              ? '${updated.fullName} can sign in again.'
              : '${updated.fullName} can no longer sign in.',
        ),
      ),
    );
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    final newRole = await showDialog<StaffRole>(
      context: context,
      builder: (_) => _ChangeRoleDialog(
        currentRole: staff.role,
        canGrantOwner: ref.read(authStateProvider)?.role == StaffRole.owner,
      ),
    );
    if (newRole == null || newRole == staff.role) return;

    final updated = await ref
        .read(staffActionControllerProvider.notifier)
        .updateRole(staffId: staff.id, role: newRole);
    if (!context.mounted) return;

    if (updated == null) {
      final error = ref.read(staffActionControllerProvider).error;
      showActionErrorSnackBar(context, message: readableErrorMessage(error));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${updated.fullName} is now a ${updated.role.label}.'),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${staff.fullName}?',
      message:
          'They lose access to this organization. Their account and any '
          'other organizations they belong to are not affected. Someone '
          'with recorded activity here can only be deactivated.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await ref
        .read(staffActionControllerProvider.notifier)
        .removeMember(staff.id);
    if (!context.mounted) return;

    if (!success) {
      final error = ref.read(staffActionControllerProvider).error;
      showActionErrorSnackBar(context, message: readableErrorMessage(error));
      return;
    }
    // The result (not a snackbar here) tells the roster screen to show
    // the confirmation — this Scaffold, and its ScaffoldMessenger, are
    // gone the moment this pop completes.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authStateProvider);
    final isAdmin = currentUser?.role.isAdminLevel ?? false;
    final isSelf = currentUser?.id == staff.id;
    final isSaving = ref.watch(staffActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(staff.fullName),
        actions: [
          if (isAdmin && !isSelf)
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Remove from organization',
              onPressed: isSaving ? null : () => _remove(context, ref),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(staffProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppSpacing.lg,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.call_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(staff.phone, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Role: ${staff.role.label}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Joined ${DateFormat('d MMM yyyy').format(staff.joinedOn)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Change role',
                          variant: AppButtonVariant.secondary,
                          onPressed: isSaving
                              ? null
                              : () => _changeRole(context, ref),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: staff.isActive ? 'Deactivate' : 'Reactivate',
                          isLoading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () => _toggleActive(context, ref),
                        ),
                      ),
                    ],
                  ),
                  // Email accounts reset their own password by email.
                  if (!isSelf && !staff.phone.contains('@'))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ResetPinButton(staff: staff),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChangeRoleDialog extends StatefulWidget {
  const _ChangeRoleDialog({
    required this.currentRole,
    required this.canGrantOwner,
  });

  final StaffRole currentRole;

  /// Only an Owner can make (or unmake) another Owner.
  final bool canGrantOwner;

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  late StaffRole _role = widget.currentRole;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change role'),
      content: AppDropdownField<StaffRole>(
        label: 'Role',
        value: _role,
        items: [
          for (final role in StaffRole.values)
            if (role != StaffRole.owner ||
                widget.canGrantOwner ||
                widget.currentRole == StaffRole.owner)
              role,
        ],
        itemLabel: (role) => role.label,
        onChanged: (role) => setState(() => _role = role!),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(_role),
        ),
      ],
    );
  }
}
