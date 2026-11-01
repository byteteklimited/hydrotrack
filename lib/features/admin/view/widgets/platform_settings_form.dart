import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/platform_settings.dart';
import '../../data/providers/admin_providers.dart';

/// Limits the server also enforces (migration 0023).
const _maxTrialDays = 90;
const _maxGraceDays = 30;

class PlatformSettingsForm extends ConsumerStatefulWidget {
  const PlatformSettingsForm({super.key, required this.settings});

  final PlatformSettings settings;

  @override
  ConsumerState<PlatformSettingsForm> createState() =>
      _PlatformSettingsFormState();
}

class _PlatformSettingsFormState extends ConsumerState<PlatformSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.settings.monthlyPrice == null
        ? ''
        : NumberFormat.decimalPattern(
            'en_NG',
          ).format(widget.settings.monthlyPrice),
  );
  late final _trialDays = TextEditingController(
    text: '${widget.settings.trialDays}',
  );
  late final _graceDays = TextEditingController(
    text: '${widget.settings.graceDays}',
  );
  late final _instructions = TextEditingController(
    text: widget.settings.paymentInstructions ?? '',
  );

  @override
  void dispose() {
    _price.dispose();
    _trialDays.dispose();
    _graceDays.dispose();
    _instructions.dispose();
    super.dispose();
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
    final saved = await ref
        .read(adminActionControllerProvider.notifier)
        .saveSettings(
          PlatformSettings(
            monthlyPrice: parseNairaText(_price.text),
            trialDays: int.parse(_trialDays.text),
            graceDays: int.parse(_graceDays.text),
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
    ).showSnackBar(const SnackBar(content: Text('Plan saved')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(adminActionControllerProvider).isLoading;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField.naira(
            label: 'Monthly price',
            controller: _price,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter the monthly price' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField.quantity(
            label: 'Free trial',
            controller: _trialDays,
            unit: 'days',
            helperText: 'For organizations created from now on',
            validator: (v) => _days(v, _maxTrialDays),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField.quantity(
            label: 'Grace period',
            controller: _graceDays,
            unit: 'days',
            helperText:
                'Days after the trial or paid time before an organization '
                'becomes read-only. Applies to everyone.',
            validator: (v) => _days(v, _maxGraceDays),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'How to pay',
            controller: _instructions,
            maxLines: 4,
            helperText:
                'Shown to owners, e.g. bank name, account number and name, '
                'and where to send the receipt.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save plan',
            isLoading: busy,
            onPressed: busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
