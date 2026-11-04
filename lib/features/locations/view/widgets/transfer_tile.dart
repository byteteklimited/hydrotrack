import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/stock_transfer.dart';
import '../../data/providers/transfer_providers.dart';
import '../../../../core/theme/brand_palette.dart';

/// One transfer: where from/to, what, and "Receive" when it's on its way
/// here.
class TransferTile extends ConsumerWidget {
  const TransferTile({super.key, required this.transfer});

  final StockTransfer transfer;

  Future<void> _receive(BuildContext context, WidgetRef ref) async {
    final done = await ref
        .read(transfersActionControllerProvider.notifier)
        .receive(transfer.id);
    if (!done && context.mounted) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(transfersActionControllerProvider).error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(transfersActionControllerProvider).isLoading;
    final (label, color) = transfer.received
        ? ('Received', AppColors.successFg)
        : transfer.incoming
        ? ('On its way here', AppColors.warningFg)
        : ('Sent', context.brand.primaryText);
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        title: transfer.incoming
            ? 'From ${transfer.fromLocation}'
            : 'To ${transfer.toLocation}',
        accentColor: transfer.toReceive ? AppColors.warningFg : null,
        trailing: AppStatusTag(label: label, color: color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in transfer.items)
              Text(formatQuantity(item.quantity, '${item.unit} ${item.name}')),
            Text(
              [
                'Sent ${DateFormat('d MMM, h:mm a').format(transfer.sentAt)}',
                ?transfer.sentBy,
                ?transfer.note,
              ].join(' · '),
              style: secondary,
            ),
            if (transfer.toReceive) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Receive',
                isLoading: busy,
                onPressed: busy ? null : () => _receive(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
