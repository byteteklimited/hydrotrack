import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/outbox_operation.dart';

/// One record waiting on this device: what it is, who made it and when,
/// and — if the server refused it — why, with Retry and (admins) Remove.
class OutboxOperationTile extends StatelessWidget {
  const OutboxOperationTile({
    super.key,
    required this.operation,
    required this.onRetry,
    this.onRemove,
  });

  final OutboxOperation operation;
  final VoidCallback onRetry;

  /// Null when the signed-in person may not remove records.
  final VoidCallback? onRemove;

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove this record?',
      message:
          'It will never reach the server. The server keeps a copy of the '
          'refused record for reference.',
      confirmLabel: 'Remove',
    );
    if (confirmed) onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refused = operation.status == OperationStatus.rejected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  operation.type.label,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppStatusTag(
                label: refused ? "Couldn't sync" : 'Waiting',
                color: refused ? AppColors.moneyOut : AppColors.textSecondary,
              ),
            ],
          ),
          Text(
            '${operation.actorName} · '
            '${formatDateTime(operation.recordedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (refused) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              operation.error ?? 'Refused by the server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.moneyOut,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onRemove != null)
                  AppButton(
                    label: 'Remove',
                    variant: AppButtonVariant.text,
                    onPressed: () => _confirmRemove(context),
                  ),
                AppButton(
                  label: 'Retry',
                  variant: AppButtonVariant.text,
                  onPressed: onRetry,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
