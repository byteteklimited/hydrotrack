import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';
import '../widgets/cost_paid_by_fields.dart';

/// Diesel put into a machine today (the generator by default). The cost is
/// recorded as a diesel expense — don't also add it under Expenses.
class LogDieselScreen extends ConsumerStatefulWidget {
  const LogDieselScreen({super.key});

  @override
  ConsumerState<LogDieselScreen> createState() => _LogDieselScreenState();
}

class _LogDieselScreenState extends ConsumerState<LogDieselScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litres = TextEditingController();
  final _cost = TextEditingController();
  final _hours = TextEditingController();
  final _note = TextEditingController();
  PaymentChannel _channel = PaymentChannel.cash;
  String? _machineId;

  @override
  void dispose() {
    for (final controller in [_litres, _cost, _hours, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Generators first, so the usual choice is the default.
  List<Machine> _choices() {
    final machines =
        ref.watch(activeMachinesProvider).valueOrNull ?? const <Machine>[];
    return [
      ...machines.where((m) => m.kind == MachineKind.generator),
      ...machines.where((m) => m.kind != MachineKind.generator),
    ];
  }

  Future<void> _save(String machineId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final note = _note.text.trim();
    final saved = await ref
        .read(machinesActionControllerProvider.notifier)
        .recordDiesel(
          machineId: machineId,
          date: DateTime.now(),
          litres: num.parse(_litres.text),
          cost: CostPaidByFields.read(_cost),
          method: _channel,
          runHours: num.tryParse(_hours.text),
          note: note.isEmpty ? null : note,
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
    final choices = _choices();
    final machineId = _machineId ?? choices.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Log diesel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (machineId == null)
              const Text(
                'No machines yet. A manager can add the generator under '
                'Machines.',
              )
            else ...[
              AppDropdownField<String>(
                label: 'Put into',
                value: machineId,
                items: [for (final m in choices) m.id],
                itemLabel: (id) => choices.firstWhere((m) => m.id == id).name,
                onChanged: (id) => setState(() => _machineId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField.decimal(
                hint: 'e.g. 25',
                label: 'Litres',
                controller: _litres,
                unit: 'litres',
                validator: (v) => (num.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'Enter the litres put in',
              ),
              const SizedBox(height: AppSpacing.md),
              CostPaidByFields(
                label: 'Cost',
                cost: _cost,
                channel: _channel,
                onChannelChanged: (c) => setState(() => _channel = c),
                required: true,
                helperText: 'Recorded as a diesel expense',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField.decimal(
                hint: 'e.g. 8',
                label: 'Hours run since last fill (optional)',
                controller: _hours,
                unit: 'hours',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                hint: 'e.g. Bought at Total, Zoo Road',
                label: 'Note (optional)',
                controller: _note,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save diesel',
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
