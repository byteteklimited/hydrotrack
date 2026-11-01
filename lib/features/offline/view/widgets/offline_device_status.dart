import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/services/offline_controller.dart';

/// This device's offline state in words: its name, when it last synced,
/// and what's waiting or was refused.
class OfflineDeviceStatus extends StatelessWidget {
  const OfflineDeviceStatus({super.key, required this.state});

  final OfflineState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final lastSynced = state.lastSyncedAt ?? state.snapshot?.pulledAt;
    final pending = state.pending.length;
    final rejected = state.rejected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'On · ${state.device!.deviceName}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          lastSynced == null
              ? 'Not synced yet'
              : 'Last synced ${formatRelativeTime(lastSynced.toLocal())}',
          style: secondary,
        ),
        Text(
          pending == 0
              ? 'Every record made here has reached the server.'
              : '$pending ${pending == 1 ? 'record' : 'records'} waiting to '
                    'sync.',
          style: secondary,
        ),
        if (rejected > 0)
          Text(
            "$rejected ${rejected == 1 ? 'record' : 'records'} couldn't sync. "
            'Open "Records on this device" to review.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.moneyOut,
            ),
          ),
        if (state.lastSyncError != null)
          Text(
            state.lastSyncError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.moneyOut,
            ),
          ),
      ],
    );
  }
}
