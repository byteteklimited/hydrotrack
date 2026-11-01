import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../widgets/auth_page_layout.dart';

/// Sign in. Staff use their phone number and PIN; organization owners who
/// created an account with email use that and their password. From here,
/// new owners create an account and new staff join with an invite code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _secretController = TextEditingController();

  bool get _isEmail => _identifierController.text.contains('@');

  @override
  void dispose() {
    _identifierController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final signedIn = await ref
        .read(signInControllerProvider.notifier)
        .signIn(
          identifier: _identifierController.text.trim(),
          secret: _isEmail
              ? _secretController.text
              : _secretController.text.trim(),
        );
    if (!signedIn || !mounted) return;
    try {
      await enterApp(context, ref);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.organizations);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signInState = ref.watch(signInControllerProvider);

    return AuthPageLayout(
      title: 'Sign in',
      subtitle: 'Staff: phone number and PIN. Owners: email and password.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Phone number or email',
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.person_outline),
              validator: Validators.phoneOrEmail,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'PIN or password',
              controller: _secretController,
              obscureText: true,
              prefixIcon: const Icon(Icons.lock_outline),
              validator: (value) => _isEmail
                  ? Validators.required(value, 'Enter your password')
                  : Validators.pin(value),
            ),
            if (signInState.hasError) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppInlineAlert(
                message:
                    'Those sign-in details are incorrect. Check and try again.',
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Sign in',
              onPressed: signInState.isLoading ? null : _submit,
              isLoading: signInState.isLoading,
              expanded: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Join your team with an invite code',
              variant: AppButtonVariant.text,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.joinWithInvite),
            ),
            AppButton(
              label: 'New business? Create an owner account',
              variant: AppButtonVariant.text,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.signUp),
            ),
          ],
        ),
      ),
    );
  }
}
