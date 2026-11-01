import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/providers/machines_providers.dart';
import 'machine_dialogs.dart';

/// Machines stopped right now, with "Mark fixed". Hidden when none are.
class OpenBreakdownsCard extends ConsumerWidget {
  const OpenBreakdownsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = [
      for (final breakdown
          in ref.watch(breakdownsProvider).valueOrNull ?? const [])
        if (breakdown.isOpen) breakdown,
    ];
    if (open.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final machine in ref.watch(machinesProvider).valueOrNull ?? [])
        machine.id: machine.name,
    };
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        title: 'Stopped now',
        accentColor: AppColors.dangerFg,
        child: Column(
          children: [
            for (final breakdown in open)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(names[breakdown.machineId] ?? 'Machine'),
                subtitle: Text(
                  '${breakdown.cause} · since '
                  '${DateFormat('EEE h:mm a').format(breakdown.startedAt)} '
                  '(${formatPlain(breakdown.downtimeHours(now))} '
                  'hours)',
                ),
                trailing: TextButton(
                  onPressed: () => showFixBreakdownDialog(
                    context,
                    breakdown,
                    names[breakdown.machineId] ?? 'Machine',
                  ),
                  child: const Text('Mark fixed'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
