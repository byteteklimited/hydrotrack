import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/batch_trace.dart';

/// The batch, where its bags are, and every sale that got them.
class BatchTraceView extends StatelessWidget {
  const BatchTraceView({super.key, required this.trace});

  final BatchTrace trace;

  (String, Color) get _waterTag => switch (trace.waterTestsPassed) {
    true => ('Water test passed', AppColors.successFg),
    false => ('Water test failed', AppColors.dangerFg),
    null => ('No water test', AppColors.warningFg),
  };

  @override
  Widget build(BuildContext context) {
    final (waterLabel, waterColor) = _waterTag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          title: 'Batch ${trace.batchNumber}',
          trailing: AppStatusTag(label: waterLabel, color: waterColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trace.product} · ${DateFormat('d MMM yyyy').format(trace.date)} · '
                '${toBeginningOfSentenceCase(trace.shift)} shift · '
                '${trace.machine}',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${trace.quantityProduced} bags made · ${trace.bagsSold} sold · '
                '${trace.bagsInStock} still in stock',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          trace.sales.isEmpty
              ? 'No bags from this batch have been sold yet.'
              : 'Customers who got this batch',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final sale in trace.sales) _SaleTile(sale: sale),
      ],
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final BatchSale sale;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        title: sale.customerName ?? 'Walk-in customer',
        trailing: sale.voided
            ? const AppStatusTag(label: 'Voided', color: AppColors.dangerFg)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sale.bags} bags · '
              '${DateFormat('d MMM yyyy, h:mm a').format(sale.dateTime)}',
            ),
            if (sale.customerPhone != null)
              SelectableText(sale.customerPhone!, style: secondary),
            if (sale.driverName != null)
              Text('Delivered by ${sale.driverName}', style: secondary),
          ],
        ),
      ),
    );
  }
}
