import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/debts_providers.dart';

/// Adds a new distributor/credit customer. Starts at zero balance — no
/// fabricated history, just a real account ready for its first sale or
/// payment.
class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _creditLimitController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final created = await ref
        .read(debtActionControllerProvider.notifier)
        .createCustomer(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          area: toTitleCase(_areaController.text.trim()),
          creditLimit:
              num.tryParse(_creditLimitController.text.replaceAll(',', '')) ??
              0,
        );
    if (!mounted) return;

    if (created == null) {
      showActionErrorSnackBar(context);
      return;
    }

    // This screen is shown as a modal (see DebtsScreen) — pop with the
    // created customer instead of navigating to their detail screen
    // directly, so the caller (which outlives this modal) can open it
    // as its own modal once this one has actually closed.
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(debtActionControllerProvider).isLoading;

    final fields = [
      AppTextField(
        label: 'Name',
        controller: _nameController,
        validator: (value) => (value == null || value.trim().isEmpty)
            ? "Enter the customer's name."
            : null,
      ),
      AppTextField(
        label: 'Phone number',
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        validator: (value) => (value == null || value.trim().length != 11)
            ? 'Enter a valid 11-digit phone number'
            : null,
      ),
      AppTextField(
        label: 'Area',
        controller: _areaController,
        helperText: 'e.g. Kubwa, Nyanya, Lugbe',
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Enter the area.' : null,
      ),
      AppTextField.naira(
        label: 'Credit limit',
        controller: _creditLimitController,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Enter a credit limit.' : null,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Add customer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                ResponsiveCenter(
                  maxWidth: 680,
                  child: Column(
                    children: [
                      AppFormGrid(fields: fields),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Add customer',
                        isLoading: isSaving,
                        expanded: true,
                        onPressed: isSaving ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
