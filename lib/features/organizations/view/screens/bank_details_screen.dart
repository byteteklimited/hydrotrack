import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/bank_details.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';

/// Bank, account number and account name printed in SMS debt reminders.
/// Shown with `showAppModal`; pops with the updated [Organization].
class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key, required this.organization});

  final Organization organization;

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _bankName = TextEditingController(
    text: widget.organization.bankDetails?.bankName,
  );
  late final _accountNumber = TextEditingController(
    text: widget.organization.bankDetails?.accountNumber,
  );
  late final _accountName = TextEditingController(
    text: widget.organization.bankDetails?.accountName,
  );

  static const _maxFormWidth = 520.0;

  @override
  void dispose() {
    _bankName.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    super.dispose();
  }

  Future<void> _save(BankDetails? details) async {
    final updated = await ref
        .read(organizationActionControllerProvider.notifier)
        .saveBankDetails(
          organizationId: widget.organization.id,
          details: details,
        );
    if (updated != null && mounted) Navigator.of(context).pop(updated);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _save(
      BankDetails(
        bankName: _bankName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        accountName: _accountName.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationActionControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't save — check your connection and try again."
        : null;
    final hasSavedDetails = widget.organization.bankDetails != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Bank details for reminders')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsiveCenter(
          maxWidth: _maxFormWidth,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Bank',
                  controller: _bankName,
                  helperText: 'e.g. GTBank, Access Bank, Moniepoint',
                  validator: (value) =>
                      Validators.required(value, 'Enter the bank name'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Account number',
                  controller: _accountNumber,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      Validators.accountNumberLength,
                    ),
                  ],
                  validator: Validators.accountNumber,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Account name',
                  controller: _accountName,
                  helperText: 'Exactly as the bank shows it',
                  validator: (value) =>
                      Validators.required(value, 'Enter the account name'),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInlineAlert(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save bank details',
                  onPressed: state.isLoading ? null : _submit,
                  isLoading: state.isLoading,
                  expanded: true,
                ),
                if (hasSavedDetails) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Remove bank details',
                    variant: AppButtonVariant.text,
                    onPressed: state.isLoading ? null : () => _save(null),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
