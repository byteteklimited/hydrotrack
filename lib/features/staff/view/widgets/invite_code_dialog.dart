import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../organizations/data/models/invitation.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../../core/theme/brand_palette.dart';

/// Shows a freshly issued invite code with exactly what the person needs
/// to do with it, and copies the whole message for WhatsApp/SMS.
Future<void> showInviteCodeDialog(BuildContext context, Invitation invitation) {
  return showDialog<void>(
    context: context,
    builder: (_) => _InviteCodeDialog(invitation: invitation),
  );
}

class _InviteCodeDialog extends ConsumerWidget {
  const _InviteCodeDialog({required this.invitation});

  final Invitation invitation;

  String get _expires =>
      DateFormat('d MMM').format(invitation.expiresAt.toLocal());

  /// Names the organization, never the platform (white label).
  String _shareMessage(String organization) {
    return 'Hi ${invitation.fullName}, you\'ve been invited to join '
        '$organization as ${invitation.role.label}. Open the app, tap '
        '"Join your team with an invite code", enter ${invitation.code} '
        'and choose a ${Validators.pinLength}-digit PIN. You\'ll sign in with '
        '${invitation.sentTo}. The code works once and expires on $_expires.';
  }

  Future<void> _copy(BuildContext context, String organization) async {
    await Clipboard.setData(ClipboardData(text: _shareMessage(organization)));
    if (!context.mounted) return;
    // Looked up before popping: this dialog's context is gone after.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Invite message copied.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization =
        ref.watch(currentOrganizationProvider)?.name ?? 'our team';
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Invite code for ${invitation.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            invitation.code,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: context.brand.primaryText,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Send this to ${invitation.sentTo}. They join from the sign-in '
            'screen with "Join your team with an invite code" and choose '
            'their own PIN. It works once and expires on $_expires.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Done',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Copy invite message',
          leadingIcon: Icons.copy,
          onPressed: () => _copy(context, organization),
        ),
      ],
    );
  }
}
