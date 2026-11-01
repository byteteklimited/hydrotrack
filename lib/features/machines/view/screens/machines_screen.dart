import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/providers/machines_providers.dart';
import '../widgets/machine_dialogs.dart';
import '../widgets/machine_month_card.dart';
import '../widgets/machine_tile.dart';
import '../widgets/maintenance_due_card.dart';
import '../widgets/open_breakdowns_card.dart';
import 'log_diesel_screen.dart';
import 'machine_detail_screen.dart';
import 'report_breakdown_screen.dart';

/// Machines and generator: what's stopped, maintenance due, diesel, and
/// this month's figures (diesel per bag, downtime).
class MachinesScreen extends ConsumerWidget {
  const MachinesScreen({super.key});

  static const _maxContentWidth = 720.0;

  Future<void> _refresh(WidgetRef ref) async {
    for (final provider in [
      machinesProvider,
      maintenanceTasksProvider,
      breakdownsProvider,
      dieselLogsProvider,
      machineReportProvider,
    ]) {
      ref.invalidate(provider);
    }
    await ref.read(machinesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machinesProvider);
    final canManage = ref.watch(authStateProvider)?.role.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machines'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add machine',
              onPressed: () => showMachineFormDialog(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ResponsiveCenter(
              maxWidth: _maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Actions(),
                  const SizedBox(height: AppSpacing.lg),
                  const OpenBreakdownsCard(),
                  const MaintenanceDueCard(),
                  const MachineMonthCard(),
                  const SizedBox(height: AppSpacing.lg),
                  machinesAsync.when(
                    loading: () =>
                        const AppLoading(message: 'Loading machines…'),
                    error: (error, stackTrace) => AppErrorState(
                      message:
                          readableErrorMessage(error) ??
                          "Couldn't load machines. Check your connection and "
                              'try again.',
                      onRetry: () => ref.invalidate(machinesProvider),
                    ),
                    data: (machines) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (machines.isEmpty)
                          const Text(
                            'No machines yet. Add your sachet machines, '
                            'generator and pumps with + above.',
                          ),
                        for (final machine in machines)
                          MachineTile(
                            machine: machine,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MachineDetailScreen(machineId: machine.id),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'Log diesel',
          leadingIcon: Icons.local_gas_station_outlined,
          onPressed: () => showAppModal<void>(
            context,
            builder: (_) => const LogDieselScreen(),
          ),
        ),
        AppButton(
          label: 'Report breakdown',
          variant: AppButtonVariant.secondary,
          leadingIcon: Icons.build_outlined,
          onPressed: () => showAppModal<void>(
            context,
            builder: (_) => const ReportBreakdownScreen(),
          ),
        ),
      ],
    );
  }
}
