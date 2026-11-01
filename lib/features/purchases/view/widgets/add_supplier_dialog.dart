import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/supplier.dart';
import '../../data/providers/purchases_providers.dart';

/// Adds a supplier (name, optional phone); returns it.
Future<Supplier?> showAddSupplierDialog(BuildContext context) {
  return showDialog<Supplier>(
    context: context,
    builder: (_) => const _AddSupplierDialog(),
  );
}

class _AddSupplierDialog extends ConsumerStatefulWidget {
  const _AddSupplierDialog();

  @override
  ConsumerState<_AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends ConsumerState<_AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final supplier = await ref
        .read(purchaseActionControllerProvider.notifier)
        .createSupplier(name: _name.text.trim(), phone: _phone.text.trim());
    if (!mounted) return;
    if (supplier == null) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(purchaseActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop(supplier);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(purchaseActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Add supplier'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Name',
              controller: _name,
              validator: (v) =>
                  Validators.required(v, 'Enter the supplier name'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Phone (optional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
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
        AppButton(
          label: 'Add supplier',
          isLoading: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
