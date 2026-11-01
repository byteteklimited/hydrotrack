import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/stock_batch.dart';
import 'batch_expiry_color.dart';

/// One row in an item's batch breakdown — received date, remaining out
/// of what came in, and its expiry if it has one. Depleted batches read
/// as spent, not as a problem — only [BatchExpiryStatus] gets a color.
class BatchTile extends StatelessWidget {
  const BatchTile({super.key, required this.batch, required this.unit});

  final StockBatch batch;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiryColor = batch.expiryStatus.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Received ${DateFormat.yMMMd().format(batch.receivedAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (batch.expiryDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    batch.expiryStatus == BatchExpiryStatus.expired
                        ? 'Expired ${DateFormat.yMMMd().format(batch.expiryDate!)}'
                        : 'Expires ${DateFormat.yMMMd().format(batch.expiryDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: expiryColor ?? theme.colorScheme.onSurfaceVariant,
                      fontWeight: expiryColor != null ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${batch.quantityRemaining} / ${batch.quantityReceived} $unit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: batch.isDepleted
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
