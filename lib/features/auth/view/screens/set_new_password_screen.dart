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

/// Opened from a password reset email: choose a new password, then carry
/// on into the app.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final done = await ref
        .read(accountSetupControllerProvider.notifier)
        .setNewPassword(_password.text);
    if (!done || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password changed.')));
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
              "Couldn't change your password. The link may have expired; "
                  'request a new one.'
        : null;

    return AuthPageLayout(
      title: 'Set a new password',
      subtitle:
          'Choose a password with at least '
          '${Validators.passwordMinLength} characters.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              hint: 'At least 8 characters',
              label: 'New password',
              controller: _password,
              obscureText: true,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              hint: 'Type the new password again',
              label: 'Confirm password',
              controller: _confirm,
              obscureText: true,
              validator: (value) =>
                  value == _password.text ? null : "Passwords don't match",
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(message: error),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Save password',
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
