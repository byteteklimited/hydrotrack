import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/connectivity.dart';
import '../../data/providers/offline_providers.dart';
import '../../data/services/offline_controller.dart';

/// Slim app-wide strip: no internet (and whether this device keeps
/// working offline), records being sent, or records that couldn't sync.
/// Tapping it opens the records on this device. Hidden when all is well.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.onOpenRecords});

  final VoidCallback onOpenRecords;

  static String? message({
    required bool isConnected,
    required OfflineState offline,
  }) {
    final pending = offline.pending.length;
    final rejected = offline.rejected.length;
    String records(int count) => count == 1 ? '1 record' : '$count records';

    if (rejected > 0) {
      return "${records(rejected)} couldn't sync. Tap to review.";
    }
    if (!isConnected) {
      if (offline.device == null) return 'No internet connection';
      return pending == 0
          ? 'No internet · working offline'
          : 'No internet · working offline · ${records(pending)} waiting '
                'to sync';
    }
    if (pending > 0) return 'Sending ${records(pending)}…';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider).valueOrNull ?? true;
    final offline = ref.watch(offlineControllerProvider);
    final text = message(isConnected: isConnected, offline: offline);
    if (text == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final problem = offline.rejected.isNotEmpty;
    final color = problem
        ? AppColors.moneyOut
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: offline.device == null ? null : onOpenRecords,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.sync : Icons.cloud_off_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
