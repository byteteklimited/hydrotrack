import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_time_field.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';

/// A machine has stopped: which, since when, and why. Mark it fixed when
/// it runs again (with the repair cost).
class ReportBreakdownScreen extends ConsumerStatefulWidget {
  const ReportBreakdownScreen({super.key, this.machineId});

  /// Preselected machine, when opened from that machine's page.
  final String? machineId;

  @override
  ConsumerState<ReportBreakdownScreen> createState() =>
      _ReportBreakdownScreenState();
}

class _ReportBreakdownScreenState extends ConsumerState<ReportBreakdownScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cause = TextEditingController();
  late String? _machineId = widget.machineId;
  DateTime _startedAt = DateTime.now();

  @override
  void dispose() {
    _cause.dispose();
    super.dispose();
  }

  Future<void> _save(String machineId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(machinesActionControllerProvider.notifier)
        .reportBreakdown(
          machineId: machineId,
          startedAt: _startedAt,
          cause: _cause.text.trim(),
        );
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(machinesActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(machinesActionControllerProvider).isLoading;
    final machines =
        ref.watch(activeMachinesProvider).valueOrNull ?? const <Machine>[];
    final machineId = _machineId ?? machines.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Report breakdown')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (machineId == null)
              const Text('No machines yet. A manager can add them first.')
            else ...[
              AppDropdownField<String>(
                label: 'Machine',
                value: machineId,
                items: [for (final m in machines) m.id],
                itemLabel: (id) => machines.firstWhere((m) => m.id == id).name,
                onChanged: (id) => setState(() => _machineId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              AppDateTimeField(
                label: 'Stopped at',
                value: _startedAt,
                onChanged: (value) => setState(() => _startedAt = value),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                hint: 'e.g. Sealer not heating',
                label: 'What went wrong',
                controller: _cause,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Say what went wrong' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Report breakdown',
                isLoading: busy,
                onPressed: busy ? null : () => _save(machineId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
