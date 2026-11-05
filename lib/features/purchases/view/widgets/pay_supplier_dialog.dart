import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/supplier.dart';
import '../../data/providers/purchases_providers.dart';

Future<void> showPaySupplierDialog(BuildContext context, Supplier supplier) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PaySupplierDialog(supplier: supplier),
  );
}

class _PaySupplierDialog extends ConsumerStatefulWidget {
  const _PaySupplierDialog({required this.supplier});

  final Supplier supplier;

  @override
  ConsumerState<_PaySupplierDialog> createState() => _PaySupplierDialogState();
}

class _PaySupplierDialogState extends ConsumerState<_PaySupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentChannel _channel = PaymentChannel.transfer;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final paid = await ref
        .read(purchaseActionControllerProvider.notifier)
        .paySupplier(
          supplierId: widget.supplier.id,
          amount: parseNairaText(_amount.text),
          channel: _channel,
          date: DateTime.now(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    if (!paid) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(purchaseActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(purchaseActionControllerProvider).isLoading;
    return AlertDialog(
      title: Text('Pay ${widget.supplier.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We owe ${formatNaira(widget.supplier.balance)}.'),
            const SizedBox(height: AppSpacing.md),
            AppTextField.naira(
              hint: 'e.g. 10,000',
              label: 'Amount',
              controller: _amount,
              validator: (v) =>
                  parseNairaText(v ?? '') > 0 ? null : 'Enter an amount',
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdownField<PaymentChannel>(
              label: 'Paid by',
              value: _channel,
              items: PaymentChannel.values,
              itemLabel: (c) => c.label,
              onChanged: (c) => setState(() => _channel = c!),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: 'e.g. Paid by transfer',
              label: 'Note (optional)',
              controller: _note,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Pay', isLoading: busy, onPressed: busy ? null : _pay),
      ],
    );
  }
}
