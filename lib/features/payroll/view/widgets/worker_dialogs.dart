import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../staff/data/models/staff_member.dart';
import '../../../staff/data/providers/staff_providers.dart';
import '../../data/models/worker.dart';
import '../../data/providers/payroll_providers.dart';

Future<void> showWorkerFormDialog(
  BuildContext context, {
  Worker? worker,
  num? rate,
}) => showDialog<void>(
  context: context,
  builder: (_) => _WorkerFormDialog(worker: worker, rate: rate),
);

Future<void> showAdvanceDialog(BuildContext context, Worker worker) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AdvanceDialog(worker: worker),
    );

String? _optional(TextEditingController controller) =>
    controller.text.trim().isEmpty ? null : controller.text.trim();

mixin _PayrollDialog<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final formKey = GlobalKey<FormState>();

  PayrollActionController get controller =>
      ref.read(payrollActionControllerProvider.notifier);
  bool get busy => ref.watch(payrollActionControllerProvider).isLoading;
  Object? error() => ref.read(payrollActionControllerProvider).error;
}

class _WorkerFormDialog extends ConsumerStatefulWidget {
  const _WorkerFormDialog({this.worker, this.rate});

  final Worker? worker;
  final num? rate;

  @override
  ConsumerState<_WorkerFormDialog> createState() => _WorkerFormDialogState();
}

class _WorkerFormDialogState extends ConsumerState<_WorkerFormDialog>
    with _PayrollDialog {
  late final _name = TextEditingController(text: widget.worker?.name);
  late final _phone = TextEditingController(text: widget.worker?.phone);
  late final _job = TextEditingController(text: widget.worker?.jobTitle);
  late final _rate = TextEditingController(
    text: widget.rate == null
        ? ''
        : NumberFormat.decimalPattern('en_NG').format(widget.rate),
  );
  late PayType _payType = widget.worker?.payType ?? PayType.daily;
  late String? _userId = widget.worker?.userId;
  late bool _active = widget.worker?.isActive ?? true;

  @override
  void dispose() {
    for (final controller in [_name, _phone, _job, _rate]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider).valueOrNull ?? const <StaffMember>[];
    return AppFormDialog(
      formKey: formKey,
      busy: busy,
      error: error,
      title: widget.worker == null ? 'Add worker' : 'Edit worker',
      submitLabel: 'Save worker',
      onSubmit: () => controller.saveWorker(
        Worker(
          id: widget.worker?.id ?? '',
          name: _name.text.trim(),
          payType: _payType,
          isActive: _active,
          phone: _optional(_phone),
          jobTitle: _optional(_job),
          userId: _userId,
        ),
        rate: parseNairaText(_rate.text),
      ),
      fields: [
        AppTextField(
          label: 'Name',
          controller: _name,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
        ),
        AppTextField(label: 'Job, e.g. Packer (optional)', controller: _job),
        AppTextField(
          label: 'Phone (optional)',
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        AppDropdownField<PayType>(
          label: 'Paid',
          value: _payType,
          items: PayType.values,
          itemLabel: (type) => type.label,
          onChanged: (type) => setState(() => _payType = type!),
        ),
        AppTextField.naira(
          label: 'Rate (${_payType.per})',
          controller: _rate,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the rate' : null,
        ),
        AppDropdownField<String?>(
          label: 'App account (optional)',
          value: _userId,
          items: [null, for (final member in staff) member.id],
          itemLabel: (id) => id == null
              ? 'None — doesn\'t use the app'
              : staff.firstWhere((m) => m.id == id).fullName,
          onChanged: (id) => setState(() => _userId = id),
        ),
        if (widget.worker != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('On the payroll'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
      ],
    );
  }
}

class _AdvanceDialog extends ConsumerStatefulWidget {
  const _AdvanceDialog({required this.worker});

  final Worker worker;

  @override
  ConsumerState<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDialogState extends ConsumerState<_AdvanceDialog>
    with _PayrollDialog {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentChannel _channel = PaymentChannel.cash;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: formKey,
    busy: busy,
    error: error,
    title: 'Advance to ${widget.worker.name}',
    intro:
        'Paid out today as wages, and taken off their next payroll '
        'automatically.',
    submitLabel: 'Give advance',
    onSubmit: () => controller.giveAdvance(
      workerId: widget.worker.id,
      amount: parseNairaText(_amount.text),
      method: _channel,
      note: _optional(_note),
    ),
    fields: [
      AppTextField.naira(
        label: 'Amount',
        controller: _amount,
        validator: (v) =>
            parseNairaText(v ?? '') > 0 ? null : 'Enter the amount',
      ),
      AppDropdownField<PaymentChannel>(
        label: 'Paid by',
        value: _channel,
        items: PaymentChannel.values,
        itemLabel: (c) => c.label,
        onChanged: (c) => setState(() => _channel = c!),
      ),
      AppTextField(label: 'Note (optional)', controller: _note),
    ],
  );
}
