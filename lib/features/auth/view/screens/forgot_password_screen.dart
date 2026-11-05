import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/providers/auth_providers.dart';
import '../widgets/auth_page_layout.dart';

/// Owners (email accounts): get an email with a link to set a new
/// password. Staff with a PIN use a reset code instead.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sent = await ref
        .read(accountSetupControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (sent && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountSetupControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't send the email. Check your connection and try again."
        : null;

    return AuthPageLayout(
      title: 'Forgot your password?',
      subtitle:
          "Enter your account's email and we'll send you a link to set a "
          'new password.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              hint: 'e.g. you@yourbusiness.com',
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: Validators.email,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(message: error),
            ],
            if (_sent) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(
                severity: AppAlertSeverity.info,
                message:
                    'If an account uses ${_email.text.trim()}, a reset link is '
                    'on its way. Open it on this device to set a new password. '
                    'Check spam if it hasn\'t arrived in a few minutes.',
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: _sent ? 'Send again' : 'Send reset link',
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
