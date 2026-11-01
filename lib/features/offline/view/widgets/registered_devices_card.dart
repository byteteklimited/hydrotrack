import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/registered_device.dart';
import '../../data/providers/offline_providers.dart';

/// Organization settings (online): every device set up for offline use,
/// with "Switch off" for a lost or retired one. Hidden when there are none
/// or the list can't be loaded (e.g. offline).
class RegisteredDevicesCard extends ConsumerWidget {
  const RegisteredDevicesCard({super.key});

  Future<void> _switchOff(
    BuildContext context,
    WidgetRef ref,
    RegisteredDevice device,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Switch off ${device.name}?',
      message:
          "It won't be able to download data or send records any more, and "
          "staff can't sign in on it offline. Records it hasn't sent yet "
          'stay on it.',
      confirmLabel: 'Switch off',
    );
    if (!confirmed || !context.mounted) return;
    final done = await ref
        .read(offlineDeviceControllerProvider.notifier)
        .revoke(device.id);
    if (!context.mounted || done) return;
    showActionErrorSnackBar(
      context,
      message: readableErrorMessage(
        ref.read(offlineDeviceControllerProvider).error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices =
        ref.watch(registeredDevicesProvider).valueOrNull ?? const [];
    if (devices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        title: 'Devices set up for offline use',
        child: Column(
          children: [
            for (final device in devices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.name, style: theme.textTheme.titleSmall),
                          Text(
                            device.lastSeenAt == null
                                ? 'Set up ${formatRelativeTime(device.createdAt.toLocal())}'
                                : 'Last synced ${formatRelativeTime(device.lastSeenAt!.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (device.isActive)
                      AppButton(
                        label: 'Switch off',
                        variant: AppButtonVariant.text,
                        onPressed: () => _switchOff(context, ref, device),
                      )
                    else
                      const AppStatusTag(
                        label: 'Switched off',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
