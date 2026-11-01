import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';

/// One machine: running or stopped, and this month's bags and downtime.
class MachineTile extends ConsumerWidget {
  const MachineTile({super.key, required this.machine, required this.onTap});

  final Machine machine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopped = (ref.watch(breakdownsProvider).valueOrNull ?? const []).any(
      (b) => b.isOpen && b.machineId == machine.id,
    );
    final row = ref
        .watch(machineReportProvider)
        .valueOrNull
        ?.forMachine(machine.id);
    final (label, color) = !machine.isActive
        ? ('Retired', AppColors.textTertiary)
        : stopped
        ? ('Stopped', AppColors.dangerFg)
        : ('Running', AppColors.successFg);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        title: machine.name,
        trailing: AppStatusTag(label: label, color: color),
        child: Text(
          [
            machine.kind.label,
            if (row != null && machine.kind != MachineKind.generator)
              '${formatQuantity(row.bags, 'bags')} this month',
            if (row != null && row.litres > 0)
              '${formatPlain(row.litres)} litres diesel',
            if (row != null && row.downtimeHours > 0)
              '${formatPlain(row.downtimeHours)} hours down',
          ].join(' · '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
