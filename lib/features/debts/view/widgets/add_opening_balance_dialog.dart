import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';
import '../../data/providers/debts_providers.dart';

/// Opens the "Opening balance" dialog for [customer] — a debt/credit
/// position that predates this system (migrating from paper records,
/// or correcting a customer set up without one).
Future<void> showAddOpeningBalanceDialog(
  BuildContext context,
  Customer customer,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AddOpeningBalanceDialog(customer: customer),
  );
}

enum _OpeningDirection { customerOwed, businessOwed }

class AddOpeningBalanceDialog extends ConsumerStatefulWidget {
  const AddOpeningBalanceDialog({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<AddOpeningBalanceDialog> createState() =>
      _AddOpeningBalanceDialogState();
}

class _AddOpeningBalanceDialogState
    extends ConsumerState<AddOpeningBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  _OpeningDirection _direction = _OpeningDirection.customerOwed;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final magnitude =
        num.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final amount = _direction == _OpeningDirection.customerOwed
        ? magnitude
        : -magnitude;

    await ref
        .read(debtActionControllerProvider.notifier)
        .addOpeningBalance(
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
      title: const Text('Opening balance'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A debt or credit from before this system — not a new '
              'sale or payment.',
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<_OpeningDirection>(
              segments: const [
                ButtonSegment(
                  value: _OpeningDirection.customerOwed,
                  label: Text('Customer owed us'),
                ),
                ButtonSegment(
                  value: _OpeningDirection.businessOwed,
                  label: Text('We owed customer'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) =>
                  setState(() => _direction = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField.naira(
              label: 'Amount',
              controller: _amountController,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter the amount.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
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
          label: 'Save',
          isLoading: isSaving,
          onPressed: isSaving ? null : _save,
        ),
      ],
    );
  }
}
