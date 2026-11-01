import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/payroll.dart';
import '../../data/providers/payroll_providers.dart';

Future<void> showAdjustLineDialog(BuildContext context, PayrollLine line) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AdjustLineDialog(line: line),
    );

Future<void> showPayPayrollDialog(BuildContext context, Payroll payroll) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PayPayrollDialog(payroll: payroll),
    );

class _AdjustLineDialog extends ConsumerStatefulWidget {
  const _AdjustLineDialog({required this.line});

  final PayrollLine line;

  @override
  ConsumerState<_AdjustLineDialog> createState() => _AdjustLineDialogState();
}

enum _Direction { add, take }

class _AdjustLineDialogState extends ConsumerState<_AdjustLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.line.adjustment == 0
        ? ''
        : NumberFormat.decimalPattern(
            'en_NG',
          ).format(widget.line.adjustment.abs()),
  );
  late final _note = TextEditingController(text: widget.line.adjustmentNote);
  late _Direction _direction = widget.line.adjustment < 0
      ? _Direction.take
      : _Direction.add;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseNairaText(_amount.text);
    return AppFormDialog(
      formKey: _formKey,
      busy: ref.watch(payrollActionControllerProvider).isLoading,
      error: () => ref.read(payrollActionControllerProvider).error,
      title: 'Adjust ${widget.line.workerName}',
      intro:
          'A bonus or a deduction; the reason shows on the payslip. '
          'Leave the amount empty to remove an adjustment.',
      submitLabel: 'Save',
      onSubmit: () => ref
          .read(payrollActionControllerProvider.notifier)
          .adjustLine(
            widget.line.id,
            _direction == _Direction.take ? -amount : amount,
            _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
      fields: [
        SegmentedButton<_Direction>(
          segments: const [
            ButtonSegment(value: _Direction.add, label: Text('Add (bonus)')),
            ButtonSegment(value: _Direction.take, label: Text('Take off')),
          ],
          selected: {_direction},
          onSelectionChanged: (selection) =>
              setState(() => _direction = selection.single),
        ),
        AppTextField.naira(label: 'Amount', controller: _amount),
        AppTextField(
          label: 'Reason',
          controller: _note,
          validator: (v) =>
              parseNairaText(_amount.text) > 0 && (v ?? '').trim().isEmpty
              ? 'Say what it is for'
              : null,
        ),
      ],
    );
  }
}

class _PayPayrollDialog extends ConsumerStatefulWidget {
  const _PayPayrollDialog({required this.payroll});

  final Payroll payroll;

  @override
  ConsumerState<_PayPayrollDialog> createState() => _PayPayrollDialogState();
}

class _PayPayrollDialogState extends ConsumerState<_PayPayrollDialog> {
  final _formKey = GlobalKey<FormState>();
  PaymentChannel _channel = PaymentChannel.transfer;

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: _formKey,
    busy: ref.watch(payrollActionControllerProvider).isLoading,
    error: () => ref.read(payrollActionControllerProvider).error,
    title: 'Pay ${formatNaira(widget.payroll.totalNet)}?',
    intro:
        "Each person's pay is recorded as a wages expense today and their "
        'advances are marked as taken off. The month is then closed.',
    submitLabel: 'Pay everyone',
    onSubmit: () => ref
        .read(payrollActionControllerProvider.notifier)
        .payPayroll(widget.payroll.id, _channel),
    fields: [
      AppDropdownField<PaymentChannel>(
        label: 'Paid by',
        value: _channel,
        items: PaymentChannel.values,
        itemLabel: (c) => c.label,
        onChanged: (c) => setState(() => _channel = c!),
      ),
    ],
  );
}
