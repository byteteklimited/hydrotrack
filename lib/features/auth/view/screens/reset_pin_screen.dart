import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../widgets/auth_page_layout.dart';
import '../widgets/new_pin_fields.dart';

/// Staff who forgot their PIN: enter the reset code from your owner or
/// admin and choose a new PIN; then you're signed straight in.
class ResetPinScreen extends ConsumerStatefulWidget {
  const ResetPinScreen({super.key});

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final done = await ref
        .read(accountSetupControllerProvider.notifier)
        .resetPin(code: _code.text.trim().toUpperCase(), pin: _pin.text);
    if (!done || !mounted) return;
    try {
      await enterApp(context, ref);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.organizations, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountSetupControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't reset your PIN. Check your connection and try again."
        : null;

    return AuthPageLayout(
      title: 'Reset your PIN',
      subtitle:
          'Ask your owner or admin for a reset code (Staff → your name → '
          'Reset PIN), then choose a new PIN.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              hint: 'The code from your manager',
              label: 'Reset code',
              controller: _code,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              validator: (value) =>
                  Validators.required(value, 'Enter your reset code'),
            ),
            const SizedBox(height: AppSpacing.lg),
            NewPinFields(
              pinController: _pin,
              confirmController: _confirm,
              label: 'New PIN',
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(message: error),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Set new PIN and sign in',
              onPressed: state.isLoading ? null : _submit,
              isLoading: state.isLoading,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
