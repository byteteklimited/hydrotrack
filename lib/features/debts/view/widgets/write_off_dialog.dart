import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';
import '../../data/providers/debts_providers.dart';

/// Opens the "Write off debt" dialog for [customer] — forgives a debt
/// with no payment received, pre-filled with the full outstanding
/// balance (the common case) but editable for a partial write-off.
Future<void> showWriteOffDialog(BuildContext context, Customer customer) {
  return showDialog<void>(
    context: context,
    builder: (context) => WriteOffDialog(customer: customer),
  );
}

class WriteOffDialog extends ConsumerStatefulWidget {
  const WriteOffDialog({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<WriteOffDialog> createState() => _WriteOffDialogState();
}

class _WriteOffDialogState extends ConsumerState<WriteOffDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.customer.balance > 0
        ? NumberFormat.decimalPattern('en_NG').format(widget.customer.balance)
        : '',
  );
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount =
        num.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    await ref
        .read(debtActionControllerProvider.notifier)
        .writeOffDebt(
          customerId: widget.customer.id,
          amount: amount,
          reason: _reasonController.text.trim(),
        );
    if (!mounted) return;

    final state = ref.read(debtActionControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = readableErrorMessage(error);
      showActionErrorSnackBar(context, message: message);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(debtActionControllerProvider).isLoading;

    return AlertDialog(
      title: const Text('Write off debt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Forgives the amount with no payment received — this can't "
              'be undone.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField.naira(
              hint: 'e.g. 2,000',
              label: 'Amount',
              controller: _amountController,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter the amount.';
                final amount = num.tryParse(value.replaceAll(',', ''));
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than zero.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: 'e.g. Customer moved away',
              label: 'Reason',
              controller: _reasonController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A reason is required.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Write off',
          isLoading: isSaving,
          onPressed: isSaving ? null : _save,
        ),
      ],
    );
  }
}
