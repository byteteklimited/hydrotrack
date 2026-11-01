import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../organizations/data/models/organization.dart';
import '../../data/providers/offline_providers.dart';
import '../screens/sync_status_screen.dart';
import 'device_name_dialog.dart';
import 'offline_device_status.dart';

/// Organization settings: offline use on THIS device — set it up, see
/// its sync state, or turn it off.
class OfflineDeviceCard extends ConsumerWidget {
  const OfflineDeviceCard({super.key, required this.organization});

  final Organization organization;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(OfflineDeviceController) action,
    String success,
  ) async {
    final done = await action(
      ref.read(offlineDeviceControllerProvider.notifier),
    );
    if (!context.mounted) return;
    if (!done) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(offlineDeviceControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success)));
  }

  Future<void> _setUp(BuildContext context, WidgetRef ref) async {
    final name = await showDeviceNameDialog(context);
    if (name == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (c) => c.setUp(name),
      'This device is ready. Staff can now sign in and record without internet.',
    );
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Turn off offline use here?',
      message:
          "This removes the organization's data from this device. Staff "
          "won't be able to sign in here without internet.",
      confirmLabel: 'Turn off',
    );
    if (!confirmed || !context.mounted) return;
    await _run(context, ref, (c) => c.turnOff(), 'Offline use turned off.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineControllerProvider);
    final busy = ref.watch(offlineDeviceControllerProvider).isLoading;
    final device = state.device;
    final isThisOrganization = device?.tenantId == organization.id;
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return AppCard(
      title: 'Offline use on this device',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (device == null) ...[
            const Text(
              'Set this device up so staff can sign in and keep recording '
              'sales, payments, expenses, production, stock and deliveries '
              'without internet. Everything is sent automatically when the '
              'connection is back.',
            ),
            if (kIsWeb) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                "In a browser, records waiting to sync are lost if someone "
                "clears this browser's site data. Use the installed app on "
                'devices that will be offline often.',
                style: secondary,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Set up this device',
              leadingIcon: Icons.cloud_download_outlined,
              isLoading: busy,
              onPressed: busy ? null : () => _setUp(context, ref),
            ),
          ] else if (isThisOrganization) ...[
            OfflineDeviceStatus(state: state),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  label: 'Sync now',
                  leadingIcon: Icons.sync,
                  variant: AppButtonVariant.secondary,
                  isLoading: busy || state.syncing,
                  onPressed: busy || state.syncing
                      ? null
                      : () => _run(context, ref, (c) => c.syncNow(), 'Synced.'),
                ),
                AppButton(
                  label: 'Records on this device',
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SyncStatusScreen(),
                    ),
                  ),
                ),
                AppButton(
                  label: 'Turn off here',
                  variant: AppButtonVariant.text,
                  onPressed: busy ? null : () => _turnOff(context, ref),
                ),
              ],
            ),
          ] else ...[
            Text(
              "This device is set up for another organization. Turn that "
              'off first (signed in there) to use it offline for '
              '${organization.name}.',
              style: secondary,
            ),
          ],
        ],
      ),
    );
  }
}
