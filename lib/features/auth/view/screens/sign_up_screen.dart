import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/sign_in_result.dart';

import '../widgets/auth_page_layout.dart';

/// Owner sign-up: name, email and password. The organization itself is
/// created right after, on the organization screen — so the same step
/// works whether or not the Supabase project asks for email confirmation.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final outcome = await ref
        .read(accountSetupControllerProvider.notifier)
        .signUp(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || outcome == null) return;
    if (outcome == SignUpOutcome.confirmEmail) {
      setState(() => _awaitingConfirmation = true);
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.organizations, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountSetupControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't create your account — check your connection and try again."
        : null;

    return AuthPageLayout(
      title: 'Create an owner account',
      subtitle: 'Set up HydroTrack for your factory, then invite your staff.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Your full name',
              controller: _nameController,
              validator: (value) =>
                  Validators.required(value, 'Enter your name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              helperText: 'At least ${Validators.passwordMinLength} characters',
              validator: Validators.password,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(message: error),
            ],
            if (_awaitingConfirmation) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppInlineAlert(
                severity: AppAlertSeverity.success,
                message:
                    'Account created. Open the link we emailed you, then sign in to set up your organization.',
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Create account',
              onPressed: state.isLoading || _awaitingConfirmation
                  ? null
                  : _submit,
              isLoading: state.isLoading,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
