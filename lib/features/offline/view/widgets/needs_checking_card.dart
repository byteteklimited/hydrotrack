import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/sync_flag.dart';
import '../../data/providers/offline_providers.dart';

/// Home, for owners/admins/managers: records made offline that synced
/// with a problem to check (short stock or raw material, over a credit
/// limit). Hidden when there's nothing to check.
class NeedsCheckingCard extends ConsumerWidget {
  const NeedsCheckingCard({super.key});

  Future<void> _markChecked(
    BuildContext context,
    WidgetRef ref,
    SyncFlag flag,
  ) async {
    final done = await ref
        .read(syncFlagControllerProvider.notifier)
        .markChecked(flag.id);
    if (!context.mounted || done) return;
    showActionErrorSnackBar(
      context,
      message: readableErrorMessage(ref.read(syncFlagControllerProvider).error),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(openSyncFlagsProvider).valueOrNull ?? const [];
    if (flags.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isSaving = ref.watch(syncFlagControllerProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        title: 'Needs checking (${flags.length})',
        accentColor: AppColors.lowStockWarning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recorded offline and saved, but worth a look: do a stock '
              'count or speak to the customer, then mark it checked.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            for (final flag in flags) ...[
              const Divider(height: AppSpacing.lg),
              Text(flag.kind.label, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(flag.details, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat(
                        'd MMM, h:mm a',
                      ).format(flag.createdAt.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'Mark checked',
                    variant: AppButtonVariant.text,
                    onPressed: isSaving
                        ? null
                        : () => _markChecked(context, ref, flag),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
