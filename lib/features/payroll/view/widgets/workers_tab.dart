import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/worker.dart';
import '../../data/providers/payroll_providers.dart';
import 'pay_tab_list.dart';
import 'worker_dialogs.dart';

/// Everyone on the payroll. Owners and admins also see rates, add and
/// edit workers, and give advances.
class WorkersTab extends ConsumerWidget {
  const WorkersTab({super.key, required this.seesPay});

  final bool seesPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workersProvider);
    final rates = seesPay
        ? ref.watch(workerRatesProvider).valueOrNull ?? const <String, num>{}
        : const <String, num>{};
    final workers = workersAsync.valueOrNull;

    return PayTabList(
      children: [
        if (seesPay) ...[
          AppButton(
            label: 'Add worker',
            leadingIcon: Icons.person_add_alt,
            onPressed: () => showWorkerFormDialog(context),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (workers == null)
          workersAsync.hasError
              ? Text(
                  readableErrorMessage(workersAsync.error) ??
                      "Couldn't load workers. Check your connection.",
                )
              : const AppLoading()
        else if (workers.isEmpty)
          Text(
            seesPay
                ? 'No workers yet. Add packers, loaders, security and staff '
                      'you pay, with how they are paid.'
                : 'No workers yet.',
          )
        else
          for (final worker in workers)
            _WorkerTile(
              worker: worker,
              rate: rates[worker.id],
              seesPay: seesPay,
            ),
      ],
    );
  }
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({
    required this.worker,
    required this.rate,
    required this.seesPay,
  });

  final Worker worker;
  final num? rate;
  final bool seesPay;

  @override
  Widget build(BuildContext context) {
    final details = [
      ?worker.jobTitle,
      worker.payType.label,
      if (seesPay && rate != null)
        '${formatNaira(rate!)} ${worker.payType.per}',
      if (!worker.isActive) 'No longer on payroll',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        title: worker.name,
        onTap: seesPay
            ? () => showWorkerFormDialog(context, worker: worker, rate: rate)
            : null,
        trailing: seesPay && worker.isActive
            ? TextButton(
                onPressed: () => showAdvanceDialog(context, worker),
                child: const Text('Give advance'),
              )
            : null,
        child: Text(
          details,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
