import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../data/models/staff_member.dart';
import 'staff_table.dart';
import 'staff_tile.dart';

/// A group of staff (active or inactive) — a stacked card per member on
/// phone ([StaffTile]), a [StaffTable] with name/phone/role/joined as
/// columns from the medium breakpoint up. Same mobile-vs-table switch
/// `ExpenseLedgerSection`/`CashLedgerSection`/`DebtLedgerSection`
/// already established. No `AppCard` here either way — the caller
/// already wraps each group in its own card.
class StaffRosterSection extends StatelessWidget {
  const StaffRosterSection({
    super.key,
    required this.staff,
    required this.onTap,
  });

  final List<StaffMember> staff;
  final ValueChanged<StaffMember> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isMediumOrWider(constraints.maxWidth)) {
          return StaffTable(staff: staff, onTap: onTap);
        }

        return Column(
          children: [
            for (var i = 0; i < staff.length; i++) ...[
              StaffTile(staff: staff[i], onTap: () => onTap(staff[i])),
              if (i != staff.length - 1) const Divider(),
            ],
          ],
        );
      },
    );
  }
}
