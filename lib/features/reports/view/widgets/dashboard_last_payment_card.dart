import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../debts/data/models/recent_payment.dart';

/// Who last paid, how much, and when — a quiet confirmation that money is
/// actually coming in, not a big green claim about it.
class DashboardLastPaymentCard extends StatelessWidget {
  const DashboardLastPaymentCard({super.key, required this.payment});

  final RecentPayment? payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = this.payment;

    return AppCard(
      title: 'Last payment',
      child: payment == null
          ? const AppEmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Payments recorded in Debts will show up here.',
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatNaira(payment.amount),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${payment.customerName} · '
                        '${DateFormat('d MMM').format(payment.date)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
