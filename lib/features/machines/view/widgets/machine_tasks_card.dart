import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';
import 'machine_dialogs.dart';
import 'maintenance_due_card.dart';

/// A machine's maintenance tasks with when each is due; "Mark done" for
/// anyone, add/edit for managers.
class MachineTasksCard extends ConsumerWidget {
  const MachineTasksCard({
    super.key,
    required this.machine,
    required this.canManage,
  });

  final Machine machine;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [
      for (final task
          in ref.watch(maintenanceTasksProvider).valueOrNull ?? const [])
        if (task.machineId == machine.id && task.isActive) task,
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
    final today = DateTime.now();

    return AppCard(
      title: 'Maintenance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tasks.isEmpty)
            Text(
              canManage
                  ? 'No tasks yet. Add what needs doing regularly, e.g. '
                        '"Change filter every 30 days".'
                  : 'No maintenance tasks set up for this machine.',
            ),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${task.name} · every ${task.everyDays} days'),
              subtitle: Text(
                MaintenanceDueCard.dueText(task, today),
                style: TextStyle(
                  color: task.daysUntilDue(today) < 0
                      ? AppColors.dangerFg
                      : AppColors.textSecondary,
                ),
              ),
              onTap: canManage
                  ? () => showTaskFormDialog(
                      context,
                      machineId: machine.id,
                      task: task,
                    )
                  : null,
              trailing: TextButton(
                onPressed: () =>
                    showMaintenanceDoneDialog(context, task, machine.name),
                child: const Text('Mark done'),
              ),
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Add task',
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.add,
              onPressed: () =>
                  showTaskFormDialog(context, machineId: machine.id),
            ),
          ],
        ],
      ),
    );
  }
}
