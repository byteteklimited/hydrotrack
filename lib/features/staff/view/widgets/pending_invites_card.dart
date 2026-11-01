import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../organizations/data/models/invitation.dart';
import '../../data/providers/staff_providers.dart';
import 'invite_code_dialog.dart';

/// Invite codes that haven't been used yet (and haven't expired or been
/// revoked): who each is for, and actions to show the code again or
/// revoke it. Hidden entirely when there are none.
class PendingInvitesCard extends ConsumerWidget {
  const PendingInvitesCard({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    Invitation invitation,
  ) async {
    final revoked = await ref
        .read(staffActionControllerProvider.notifier)
        .revokeInvitation(invitation.id);
    if (!context.mounted) return;
    if (!revoked) {
      final error = ref.read(staffActionControllerProvider).error;
      showActionErrorSnackBar(context, message: readableErrorMessage(error));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite for ${invitation.fullName} revoked.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final pending = (ref.watch(invitationsProvider).valueOrNull ?? const [])
        .where((i) => i.statusAt(now) == InvitationStatus.pending)
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        title: 'Pending invites (${pending.length})',
        child: Column(
          children: [
            for (var i = 0; i < pending.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pending[i].fullName,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${pending[i].role.label} · ${pending[i].sentTo} · '
                            'expires ${DateFormat('d MMM').format(pending[i].expiresAt.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: 'Show code',
                      variant: AppButtonVariant.text,
                      onPressed: () =>
                          showInviteCodeDialog(context, pending[i]),
                    ),
                    AppButton(
                      label: 'Revoke',
                      variant: AppButtonVariant.text,
                      onPressed: () => _revoke(context, ref, pending[i]),
                    ),
                  ],
                ),
              ),
              if (i != pending.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
