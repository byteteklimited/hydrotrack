import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/customer.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/providers/debts_providers.dart';

/// One row: name, area, balance, and a plain-language line about when
/// they last paid — red once they're overdue. A customer in credit
/// (overpaid) shows that as "₦X credit", not a confusing negative
/// figure — see [Customer.isInCredit].
class DebtCustomerTile extends ConsumerWidget {
  const DebtCustomerTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overdue = customer.isOverdue;
    final inCredit = customer.isInCredit;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    toTitleCase(customer.area),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  inCredit
                      ? '${formatNaira(-customer.balance)} credit'
                      : formatNaira(customer.balance),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    // Red only once this customer is actually overdue —
                    // every row here already carries a positive balance
                    // by definition (this tile only renders in the
                    // "owing" list), so coloring on balance alone would
                    // make every row red regardless of urgency and
                    // drown out the one row that's genuinely overdue.
                    // A credit balance is never red either — see
                    // Customer.isInCredit's own doc comment.
                    color: overdue ? AppColors.moneyOut : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (overdue)
                  _AgeLine(
                    text:
                        'No payment in '
                        '${customer.lastPaymentDate == null ? 'a while' : '${DateTime.now().difference(customer.lastPaymentDate!).inDays} days'}',
                    color: AppColors.moneyOut,
                  )
                else
                  _LastPaymentLine(customer: customer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastPaymentLine extends ConsumerWidget {
  const _LastPaymentLine({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customer.lastPaymentDate == null) {
      return const SizedBox.shrink();
    }
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));
    return ledgerAsync.when(
      data: (ledger) {
        final lastPayment = ledger.lastWhere(
          (entry) => entry.type == LedgerEntryType.payment,
          orElse: () => ledger.first,
        );
        return _AgeLine(
          text:
              'Paid ${formatNaira(lastPayment.amount)} on '
              '${DateFormat('d MMM').format(customer.lastPaymentDate!)}',
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AgeLine extends StatelessWidget {
  const _AgeLine({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color ?? theme.colorScheme.onSurfaceVariant,
        fontWeight: color != null ? FontWeight.w600 : null,
      ),
    );
  }
}
