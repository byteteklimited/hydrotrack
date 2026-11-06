import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../subscriptions/data/models/bank_account.dart';
import '../../data/models/platform_settings.dart';
import '../../data/providers/admin_providers.dart';

/// Limits the server also enforces (migration 0023).
const _maxTrialDays = 90;
const _maxGraceDays = 30;
const _accountNumberLength = 10;
final _accountNumberPattern = RegExp(r'^\d{10}$');

class PlatformSettingsForm extends ConsumerStatefulWidget {
  const PlatformSettingsForm({super.key, required this.settings});

  final PlatformSettings settings;

  @override
  ConsumerState<PlatformSettingsForm> createState() =>
      _PlatformSettingsFormState();
}

class _PlatformSettingsFormState extends ConsumerState<PlatformSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _trialDays = TextEditingController(
    text: '${widget.settings.trialDays}',
  );
  late final _graceDays = TextEditingController(
    text: '${widget.settings.graceDays}',
  );
  late final _bankName = TextEditingController(
    text: widget.settings.bankAccount?.bankName ?? '',
  );
  late final _accountNumber = TextEditingController(
    text: widget.settings.bankAccount?.accountNumber ?? '',
  );
  late final _accountName = TextEditingController(
    text: widget.settings.bankAccount?.accountName ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.settings.paymentInstructions ?? '',
  );

  List<TextEditingController> get _bankFields => [
    _bankName,
    _accountNumber,
    _accountName,
  ];

  @override
  void dispose() {
    for (final controller in [
      _trialDays,
      _graceDays,
      ..._bankFields,
      _instructions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The bank fields are all filled in, or all empty.
  String? _bankField(String? value, String what) {
    final anyFilled = _bankFields.any((c) => c.text.trim().isNotEmpty);
    return anyFilled && (value ?? '').trim().isEmpty
        ? 'Enter the $what (or clear all three bank fields)'
        : null;
  }

  String? _accountNumberCheck(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return _bankField(value, 'account number');
    return _accountNumberPattern.hasMatch(text)
        ? null
        : 'The account number must be 10 digits';
  }

  static String? _days(String? value, int max) {
    final days = int.tryParse(value ?? '');
    return days != null && days >= 0 && days <= max
        ? null
        : 'Enter 0 to $max days';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final instructions = _instructions.text.trim();
    final hasBank = _bankName.text.trim().isNotEmpty;
    final saved = await ref
        .read(adminActionControllerProvider.notifier)
        .saveSettings(
          PlatformSettings(
            trialDays: int.parse(_trialDays.text),
            graceDays: int.parse(_graceDays.text),
            bankAccount: hasBank
                ? BankAccount(
                    bankName: _bankName.text.trim(),
                    accountNumber: _accountNumber.text.trim(),
                    accountName: _accountName.text.trim(),
                  )
                : null,
            paymentInstructions: instructions.isEmpty ? null : instructions,
          ),
        );
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(adminActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(adminActionControllerProvider).isLoading;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField.quantity(
            hint: 'e.g. 14',
            label: 'Free trial',
            controller: _trialDays,
            unit: 'days',
            helperText: 'For organizations created from now on',
            validator: (v) => _days(v, _maxTrialDays),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField.quantity(
            hint: 'e.g. 7',
            label: 'Grace period',
            controller: _graceDays,
            unit: 'days',
            helperText:
                'Days after the trial or paid time before an organization '
                'becomes read-only. Applies to everyone.',
            validator: (v) => _days(v, _maxGraceDays),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Where organizations pay',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            hint: 'e.g. Moniepoint MFB',
            label: 'Bank',
            controller: _bankName,
            validator: (v) => _bankField(v, 'bank'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            hint: '10 digits, e.g. 8137131177',
            label: 'Account number',
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_accountNumberLength),
            ],
            validator: _accountNumberCheck,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            hint: 'e.g. Byte Tek Limited',
            label: 'Account name',
            controller: _accountName,
            validator: (v) => _bankField(v, 'account name'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            hint: 'e.g. Send the receipt on WhatsApp to 08031234567',
            label: 'Anything else about paying (optional)',
            controller: _instructions,
            maxLines: 3,
            helperText: 'Shown to owners under the bank account.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save settings',
            isLoading: busy,
            onPressed: busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
