import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';
import '../widgets/machine_dialogs.dart';
import '../widgets/machine_history_card.dart';
import '../widgets/machine_tasks_card.dart';
import 'report_breakdown_screen.dart';

/// One machine: its maintenance tasks, breakdowns and diesel. Managers
/// edit it, retire it, and set up its tasks.
class MachineDetailScreen extends ConsumerWidget {
  const MachineDetailScreen({super.key, required this.machineId});

  final String machineId;

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machine = (ref.watch(machinesProvider).valueOrNull ?? const [])
        .where((m) => m.id == machineId)
        .firstOrNull;
    if (machine == null) {
      return Scaffold(appBar: AppBar(), body: const AppLoading());
    }
    final canManage = ref.watch(authStateProvider)?.role.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(machine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.build_outlined),
            tooltip: 'Report breakdown',
            onPressed: () => showAppModal<void>(
              context,
              builder: (_) => ReportBreakdownScreen(machineId: machine.id),
            ),
          ),
          if (canManage) _ManageMenu(machine: machine),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MachineTasksCard(machine: machine, canManage: canManage),
                const SizedBox(height: AppSpacing.lg),
                MachineHistoryCard(machine: machine),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ManageAction { edit, retire }

class _ManageMenu extends ConsumerWidget {
  const _ManageMenu({required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ManageAction>(
      onSelected: (action) => switch (action) {
        _ManageAction.edit => showMachineFormDialog(context, machine: machine),
        _ManageAction.retire =>
          ref
              .read(machinesActionControllerProvider.notifier)
              .saveMachine(
                name: machine.name,
                kind: machine.kind,
                id: machine.id,
                isActive: !machine.isActive,
              ),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: _ManageAction.edit, child: Text('Edit')),
        PopupMenuItem(
          value: _ManageAction.retire,
          child: Text(machine.isActive ? 'Retire machine' : 'Bring back'),
        ),
      ],
    );
  }
}
