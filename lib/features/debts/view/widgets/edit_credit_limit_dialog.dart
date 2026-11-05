import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/customer.dart';
import '../../data/providers/debts_providers.dart';

/// Opens the "Edit credit limit" dialog for [customer].
Future<void> showEditCreditLimitDialog(
  BuildContext context,
  Customer customer,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => EditCreditLimitDialog(customer: customer),
  );
}

class EditCreditLimitDialog extends ConsumerStatefulWidget {
  const EditCreditLimitDialog({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<EditCreditLimitDialog> createState() =>
      _EditCreditLimitDialogState();
}

class _EditCreditLimitDialogState extends ConsumerState<EditCreditLimitDialog> {
  late final _controller = TextEditingController(
    text: NumberFormat.decimalPattern(
      'en_NG',
    ).format(widget.customer.creditLimit),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newLimit = num.tryParse(_controller.text.replaceAll(',', ''));
    if (newLimit == null) return;
    await ref
        .read(debtActionControllerProvider.notifier)
        .updateCreditLimit(customerId: widget.customer.id, newLimit: newLimit);
    if (!mounted) return;

    if (ref.read(debtActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(debtActionControllerProvider).isLoading;

    return AlertDialog(
      title: const Text('Edit credit limit'),
      content: AppTextField.naira(
        hint: 'e.g. 50,000',
        label: 'Credit limit',
        controller: _controller,
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
