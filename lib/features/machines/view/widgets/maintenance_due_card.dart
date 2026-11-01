import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';
import 'machine_dialogs.dart';

/// Maintenance overdue or due within a few days, with "Mark done". Shown
/// on Home and the Machines screen; hidden when nothing is due.
class MaintenanceDueCard extends ConsumerWidget {
  const MaintenanceDueCard({super.key});

  static String dueText(MaintenanceTask task, DateTime today) {
    final days = task.daysUntilDue(today);
    if (days < 0) {
      return 'Overdue since ${DateFormat('d MMM').format(task.dueOn)}';
    }
    if (days == 0) return 'Due today';
    return days == 1 ? 'Due tomorrow' : 'Due in $days days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(maintenanceDueProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final machine in ref.watch(machinesProvider).valueOrNull ?? [])
        machine.id: machine.name,
    };
    final today = DateTime.now();
    final overdue = due.any((task) => task.daysUntilDue(today) < 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        title: 'Maintenance due',
        accentColor: overdue ? AppColors.dangerFg : AppColors.warningFg,
        child: Column(
          children: [
            for (final task in due)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${task.name} · ${names[task.machineId] ?? ''}'),
                subtitle: Text(
                  dueText(task, today),
                  style: TextStyle(
                    color: task.daysUntilDue(today) < 0
                        ? AppColors.dangerFg
                        : AppColors.warningFg,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => showMaintenanceDoneDialog(
                    context,
                    task,
                    names[task.machineId] ?? 'Machine',
                  ),
                  child: const Text('Mark done'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
