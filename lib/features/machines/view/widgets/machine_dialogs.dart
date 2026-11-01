import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/widgets/app_date_time_field.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/machine.dart';
import '../../data/providers/machines_providers.dart';
import 'cost_paid_by_fields.dart';

Future<void> showFixBreakdownDialog(
  BuildContext context,
  Breakdown breakdown,
  String machineName,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _FixBreakdownDialog(breakdown: breakdown, machineName: machineName),
);

Future<void> showMaintenanceDoneDialog(
  BuildContext context,
  MaintenanceTask task,
  String machineName,
) => showDialog<void>(
  context: context,
  builder: (_) => _MaintenanceDoneDialog(task: task, machineName: machineName),
);

Future<void> showTaskFormDialog(
  BuildContext context, {
  required String machineId,
  MaintenanceTask? task,
}) => showDialog<void>(
  context: context,
  builder: (_) => _TaskFormDialog(machineId: machineId, task: task),
);

Future<void> showMachineFormDialog(BuildContext context, {Machine? machine}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _MachineFormDialog(machine: machine),
    );

String? _optional(TextEditingController controller) =>
    controller.text.trim().isEmpty ? null : controller.text.trim();

/// What every machine dialog needs from the controller.
mixin _MachinesDialog<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final formKey = GlobalKey<FormState>();

  MachinesActionController get controller =>
      ref.read(machinesActionControllerProvider.notifier);
  bool get busy => ref.watch(machinesActionControllerProvider).isLoading;
  Object? error() => ref.read(machinesActionControllerProvider).error;
}

class _FixBreakdownDialog extends ConsumerStatefulWidget {
  const _FixBreakdownDialog({
    required this.breakdown,
    required this.machineName,
  });

  final Breakdown breakdown;
  final String machineName;

  @override
  ConsumerState<_FixBreakdownDialog> createState() =>
      _FixBreakdownDialogState();
}

class _FixBreakdownDialogState extends ConsumerState<_FixBreakdownDialog>
    with _MachinesDialog {
  final _cost = TextEditingController();
  final _note = TextEditingController();
  DateTime _endedAt = DateTime.now();
  PaymentChannel _channel = PaymentChannel.cash;

  @override
  void dispose() {
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: formKey,
    busy: busy,
    error: error,
    title: '${widget.machineName} is running again',
    intro: 'Stopped: ${widget.breakdown.cause}',
    submitLabel: 'Mark fixed',
    onSubmit: () => controller.endBreakdown(
      breakdownId: widget.breakdown.id,
      endedAt: _endedAt,
      repairCost: CostPaidByFields.read(_cost),
      method: _channel,
      note: _optional(_note),
    ),
    fields: [
      AppDateTimeField(
        label: 'Restarted at',
        value: _endedAt,
        onChanged: (value) => setState(() => _endedAt = value),
      ),
      CostPaidByFields(
        label: 'Repair cost (leave empty if none)',
        cost: _cost,
        channel: _channel,
        onChannelChanged: (c) => setState(() => _channel = c),
        helperText: 'Recorded as a maintenance expense',
      ),
      AppTextField(label: 'What was done (optional)', controller: _note),
    ],
  );
}

class _MaintenanceDoneDialog extends ConsumerStatefulWidget {
  const _MaintenanceDoneDialog({required this.task, required this.machineName});

  final MaintenanceTask task;
  final String machineName;

  @override
  ConsumerState<_MaintenanceDoneDialog> createState() =>
      _MaintenanceDoneDialogState();
}

class _MaintenanceDoneDialogState extends ConsumerState<_MaintenanceDoneDialog>
    with _MachinesDialog {
  final _cost = TextEditingController();
  final _note = TextEditingController();
  PaymentChannel _channel = PaymentChannel.cash;

  @override
  void dispose() {
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: formKey,
    busy: busy,
    error: error,
    title: '${widget.task.name} done',
    intro:
        'On ${widget.machineName}, today. Next due in '
        '${widget.task.everyDays} days.',
    submitLabel: 'Mark done',
    onSubmit: () => controller.recordMaintenance(
      taskId: widget.task.id,
      doneOn: DateTime.now(),
      cost: CostPaidByFields.read(_cost),
      method: _channel,
      note: _optional(_note),
    ),
    fields: [
      CostPaidByFields(
        label: 'Cost (leave empty if none)',
        cost: _cost,
        channel: _channel,
        onChannelChanged: (c) => setState(() => _channel = c),
        helperText: 'Recorded as a maintenance expense',
      ),
      AppTextField(label: 'Note (optional)', controller: _note),
    ],
  );
}

class _TaskFormDialog extends ConsumerStatefulWidget {
  const _TaskFormDialog({required this.machineId, this.task});

  final String machineId;
  final MaintenanceTask? task;

  @override
  ConsumerState<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<_TaskFormDialog>
    with _MachinesDialog {
  static const _maxEveryDays = 730;

  late final _name = TextEditingController(text: widget.task?.name);
  late final _every = TextEditingController(
    text: widget.task?.everyDays.toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _every.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: formKey,
    busy: busy,
    error: error,
    title: widget.task == null ? 'Add maintenance task' : 'Edit task',
    submitLabel: 'Save task',
    onSubmit: () => controller.saveTask(
      machineId: widget.machineId,
      name: _name.text.trim(),
      everyDays: int.parse(_every.text),
      id: widget.task?.id,
    ),
    fields: [
      AppTextField(
        label: 'Task, e.g. "Change filter"',
        controller: _name,
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the task' : null,
      ),
      AppTextField.quantity(
        label: 'Every',
        controller: _every,
        unit: 'days',
        validator: (v) {
          final days = int.tryParse(v ?? '');
          return days != null && days >= 1 && days <= _maxEveryDays
              ? null
              : 'Enter 1 to $_maxEveryDays days';
        },
      ),
    ],
  );
}

class _MachineFormDialog extends ConsumerStatefulWidget {
  const _MachineFormDialog({this.machine});

  final Machine? machine;

  @override
  ConsumerState<_MachineFormDialog> createState() => _MachineFormDialogState();
}

class _MachineFormDialogState extends ConsumerState<_MachineFormDialog>
    with _MachinesDialog {
  late final _name = TextEditingController(text: widget.machine?.name);
  late MachineKind _kind = widget.machine?.kind ?? MachineKind.production;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: formKey,
    busy: busy,
    error: error,
    title: widget.machine == null ? 'Add machine' : 'Edit machine',
    submitLabel: 'Save machine',
    onSubmit: () => controller.saveMachine(
      name: _name.text.trim(),
      kind: _kind,
      id: widget.machine?.id,
    ),
    fields: [
      AppTextField(
        label: 'Name, e.g. "Machine 3" or "Borehole pump"',
        controller: _name,
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
      ),
      AppDropdownField<MachineKind>(
        label: 'Kind',
        value: _kind,
        items: MachineKind.values,
        itemLabel: (kind) => kind.label,
        onChanged: (kind) => setState(() => _kind = kind!),
      ),
    ],
  );
}
