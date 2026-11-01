import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/sale.dart';
import 'sale_payment_status_color.dart';

/// A quiet, flat status label — not a [Chip], which reads as something
/// tappable even with no `onTap` wired up. Shows whether a sale is
/// settled, not how it was paid: paid (green, a confirmed positive
/// outcome), part-paid (amber, the existing threshold-warning color),
/// on credit (red, money still owed — the same colors this app already
/// used for payment method, now applied to the status that actually
/// matters).
class SalePaymentStatusBadge extends StatelessWidget {
  const SalePaymentStatusBadge({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final status = sale.paymentStatus;
    final color = status.color!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
