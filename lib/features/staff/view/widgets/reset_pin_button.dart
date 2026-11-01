import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/staff_member.dart';
import '../../data/providers/staff_providers.dart';

/// Owner/Admin, on a staff member who signs in with phone + PIN: issues a
/// one-time reset code and shows it, with a message to send them.
class ResetPinButton extends ConsumerWidget {
  const ResetPinButton({super.key, required this.staff});

  final StaffMember staff;

  Future<void> _issue(BuildContext context, WidgetRef ref) async {
    final reset = await ref
        .read(staffActionControllerProvider.notifier)
        .createPinReset(staff.id);
    if (!context.mounted) return;
    if (reset == null) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(staffActionControllerProvider).error,
        ),
      );
      return;
    }
    final expires = DateFormat(
      'd MMM, h:mm a',
    ).format(reset.expiresAt.toLocal());
    final message =
        'Hi ${staff.fullName}, your HydroTrack PIN reset code is '
        '${reset.code}. On the sign-in screen tap "Forgot your PIN?", enter '
        'the code and choose a new ${Validators.pinLength}-digit PIN. It '
        'works once and expires $expires.';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('PIN reset code for ${staff.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              reset.code,
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                color: AppColors.brandNavy,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Send this to ${staff.fullName}. It works once, expires $expires, '
              'and replaces any earlier code.',
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Done',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: 'Copy message',
            leadingIcon: Icons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(staffActionControllerProvider).isLoading;
    return AppButton(
      label: 'Reset PIN',
      leadingIcon: Icons.lock_reset,
      variant: AppButtonVariant.text,
      onPressed: busy ? null : () => _issue(context, ref),
    );
  }
}
