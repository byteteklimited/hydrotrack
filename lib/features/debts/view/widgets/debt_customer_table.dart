import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/customer.dart';
import 'debt_customer_table_row.dart';

class _DebtCustomerTableHeader extends StatelessWidget {
  const _DebtCustomerTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('Phone', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text('Balance', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              'Last payment',
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: 96, child: Text('', style: style)),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of the customers list: name, phone,
/// balance, last payment, and an aging chip as aligned columns,
/// zebra-striped — same fields [DebtCustomerTile] shows stacked.
///
/// Card-less by design, like [DebtCustomerSection] itself — callers
/// (the owing/credit/settled groups on the Debts screen) each already
/// wrap their own content in an `AppCard`/`ExpansionTile`, so this
/// slots into whichever one it's given rather than nesting a second
/// card inside it.
class DebtCustomerTable extends StatelessWidget {
  const DebtCustomerTable({
    super.key,
    required this.customers,
    required this.onTap,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DebtCustomerTableHeader(),
        const Divider(height: 1),
        for (var i = 0; i < customers.length; i++)
          DebtCustomerTableRow(
            customer: customers[i],
            onTap: () => onTap(customers[i]),
            tinted: i.isOdd,
          ),
      ],
    );
  }
}
