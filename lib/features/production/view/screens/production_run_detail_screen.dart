import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/production_thresholds.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/production_run.dart';
import '../../data/providers/production_providers.dart';
import 'record_production_screen.dart';

/// Same reasoning as every other detail screen in the app: content
/// reads best at a bounded width, implemented as responsive padding so
/// `ListView` keeps its native scroll behavior.
const double _contentCap = 720;

/// A single production run, including who recorded it and when. Looks
/// itself up by [runId] from the live list (rather than taking a
/// [ProductionRun] directly) so an edit made from here is reflected
/// immediately once the list refreshes — same pattern as customer/staff
/// detail screens.
class ProductionRunDetailScreen extends ConsumerWidget {
  const ProductionRunDetailScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(productionRunsProvider);

    return runsAsync.when(
      data: (runs) {
        final run = runs.firstWhere((r) => r.id == runId);
        return _RunDetailBody(run: run);
      },
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              "Couldn't load this production run. Check your connection and try again.",
          onRetry: () => ref.invalidate(productionRunsProvider),
        ),
      ),
    );
  }
}

class _RunDetailBody extends ConsumerWidget {
  const _RunDetailBody({required this.run});

  final ProductionRun run;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this run?',
      message:
          '${run.shift.label} · ${run.machine} — ${run.quantityProduced} '
          "bags, recorded by ${run.recordedBy}. This can't be undone.",
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final success = await ref
        .read(recordProductionControllerProvider.notifier)
        .delete(run.id);
    if (!context.mounted) return;

    if (!success) {
      showActionErrorSnackBar(context);
      return;
    }
    // The result (not a snackbar here) tells the list screen to show the
    // confirmation — this Scaffold, and its ScaffoldMessenger, are gone
    // the moment this pop completes.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider)?.role;
    final canEdit = role?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${run.shift.label} · ${run.machine}'),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit run',
              onPressed: () => showAppModal(
                context,
                builder: (_) => RecordProductionScreen(existingRun: run),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete run',
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            children: [
              AppCard(
                title: DateFormat.yMMMd().format(run.date),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Shift', value: run.shift.label),
                    _DetailRow(label: 'Machine', value: run.machine),
                    _DetailRow(label: 'Product', value: run.product.label),
                    _DetailRow(label: 'Operator', value: run.operatorName),
                    _DetailRow(
                      label: 'Bags produced',
                      value: '${run.quantityProduced}',
                    ),
                    _DetailRow(
                      label: 'Wastage',
                      value:
                          '${run.wastage} bags '
                          '(${run.wastagePercent.toStringAsFixed(1)}%)',
                      valueColor: wastageColor(run.wastagePercent),
                    ),
                    _DetailRow(
                      label: 'Material cost',
                      value: run.costPerBag == null
                          ? formatNaira(run.materialCost)
                          : '${formatNaira(run.materialCost)} '
                                '(${formatNairaWithKobo(run.costPerBag!)} a bag)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                title: 'Audit trail',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Recorded by', value: run.recordedBy),
                    _DetailRow(
                      label: 'Recorded at',
                      value: DateFormat.yMMMd().add_jm().format(run.recordedAt),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
