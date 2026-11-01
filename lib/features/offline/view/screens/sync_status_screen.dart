import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/providers/offline_providers.dart';
import '../widgets/offline_device_status.dart';
import '../widgets/outbox_operation_tile.dart';

/// Records made on this device that haven't reached the server: waiting
/// ones, and ones the server refused (with why, and Retry / Remove).
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineControllerProvider);
    final controller = ref.read(offlineControllerProvider.notifier);
    final canRemove = ref.watch(authStateProvider)?.role.isAdminLevel ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Records on this device')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.device != null) ...[
                  AppCard(child: OfflineDeviceStatus(state: state)),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Sync now',
                    leadingIcon: Icons.sync,
                    isLoading: state.syncing,
                    onPressed: state.syncing ? null : controller.sync,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (state.outbox.isEmpty)
                  const AppEmptyState(
                    icon: Icons.cloud_done_outlined,
                    title: 'Everything has synced',
                    message:
                        'Records made on this device show here until the '
                        'server has them.',
                  )
                else
                  AppCard(
                    title: 'Not yet on the server (${state.outbox.length})',
                    child: Column(
                      children: [
                        for (final op in state.outbox.reversed)
                          OutboxOperationTile(
                            operation: op,
                            onRetry: () => controller.retry(op.opId),
                            onRemove: canRemove
                                ? () => controller.discard(op.opId)
                                : null,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
