import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/providers/debts_providers.dart';

/// Opens the "Record payment" sheet for [customer].
Future<void> showRecordPaymentSheet(BuildContext context, Customer customer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => RecordPaymentSheet(customer: customer),
  );
}

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  PaymentChannel _channel = PaymentChannel.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount =
        num.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    final updated = await ref
        .read(debtActionControllerProvider.notifier)
        .recordPayment(
          customerId: widget.customer.id,
          amount: amount,
          channel: _channel,
          date: _date,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;

    if (updated == null) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment recorded — ${updated.name} now owes ${formatNaira(updated.balance)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(debtActionControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record payment',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField.naira(
                  hint: 'e.g. 5,000',
                  label: 'Amount',
                  controller: _amountController,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter the amount paid.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<PaymentChannel>(
                  label: 'Method',
                  value: _channel,
                  items: PaymentChannel.values,
                  itemLabel: (channel) => channel.label,
                  onChanged: (channel) => setState(() => _channel = channel!),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: DateFormat.yMMMd().format(_date),
                  leadingIcon: Icons.calendar_today_outlined,
                  variant: AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  hint: 'e.g. Paid by his son',
                  label: 'Note (optional)',
                  controller: _noteController,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Record payment',
                  isLoading: isSaving,
                  expanded: true,
                  onPressed: isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
