import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/staff_member.dart';
import 'staff_table_row.dart';

class _StaffTableHeader extends StatelessWidget {
  const _StaffTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('PHONE', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('ROLE', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: Text('JOINED', style: style)),
        ],
      ),
    );
  }
}

/// The tablet/desktop rendering of the staff roster — name (with the
/// inactive tag inline), phone, role, and join date as aligned columns,
/// zebra-striped with the app's reserved `tableRowTint`. Join date
/// wasn't visible anywhere on the roster before this (only on the
/// detail screen). No outer `AppCard` here on purpose — both the active
/// and inactive groups in `staff_screen.dart` already wrap their
/// content in their own card; this is only ever used as that card's
/// child.
class StaffTable extends StatelessWidget {
  const StaffTable({super.key, required this.staff, required this.onTap});

  final List<StaffMember> staff;
  final ValueChanged<StaffMember> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StaffTableHeader(),
        const Divider(height: 1),
        for (var i = 0; i < staff.length; i++)
          StaffTableRow(
            staff: staff[i],
            tinted: i.isOdd,
            onTap: () => onTap(staff[i]),
          ),
      ],
    );
  }
}
