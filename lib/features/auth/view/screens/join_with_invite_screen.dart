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

/// New staff: enter the invite code your admin gave you and choose a PIN.
/// Creates a phone + PIN account for the number the invite was sent to,
/// joins the organization, and signs straight in. Someone who already has
/// an account signs in instead and joins from the organization screen.
class JoinWithInviteScreen extends ConsumerStatefulWidget {
  const JoinWithInviteScreen({super.key});

  @override
  ConsumerState<JoinWithInviteScreen> createState() =>
      _JoinWithInviteScreenState();
}

class _JoinWithInviteScreenState extends ConsumerState<JoinWithInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final joined = await ref
        .read(accountSetupControllerProvider.notifier)
        .joinWithInvite(
          code: _codeController.text.trim().toUpperCase(),
          pin: _pinController.text,
        );
    if (!joined || !mounted) return;
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
              "Couldn't join — check your connection and try again."
        : null;

    return AuthPageLayout(
      title: 'Join your team',
      subtitle: 'Enter the invite code from your admin and choose a PIN.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Invite code',
              controller: _codeController,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              validator: (value) =>
                  Validators.required(value, 'Enter your invite code'),
            ),
            const SizedBox(height: AppSpacing.lg),
            NewPinFields(
              pinController: _pinController,
              confirmController: _confirmPinController,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInlineAlert(message: error),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Join organization',
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
