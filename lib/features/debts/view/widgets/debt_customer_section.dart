import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../data/models/customer.dart';
import 'debt_customer_table.dart';
import 'debt_customer_tile.dart';

/// Stacked [DebtCustomerTile] rows on phone; [DebtCustomerTable] from
/// tablet width up — same entries either way, same
/// `LayoutBuilder`-at-medium-breakpoint switch every other list/table
/// pair in this app already uses. Card-less either way — every caller
/// on the Debts screen already wraps its own group in an `AppCard` or
/// `ExpansionTile`, so this slots into that rather than nesting a
/// second card inside it.
class DebtCustomerSection extends StatelessWidget {
  const DebtCustomerSection({
    super.key,
    required this.customers,
    required this.onTap,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return DebtCustomerTable(customers: customers, onTap: onTap);
        }

        return Column(
          children: [
            for (var i = 0; i < customers.length; i++) ...[
              DebtCustomerTile(
                customer: customers[i],
                onTap: () => onTap(customers[i]),
              ),
              if (i != customers.length - 1) const Divider(),
            ],
          ],
        );
      },
    );
  }
}
