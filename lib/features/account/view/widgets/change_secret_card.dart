import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/data/providers/auth_providers.dart';

/// Change PIN (phone accounts) or password (email accounts), after typing
/// the current one.
class ChangeSecretCard extends ConsumerStatefulWidget {
  const ChangeSecretCard({
    super.key,
    required this.identifier,
    required this.usesPassword,
  });

  /// What the person signs in with (email or phone).
  final String identifier;

  /// Email accounts have a password; phone accounts a 6-digit PIN.
  final bool usesPassword;

  @override
  ConsumerState<ChangeSecretCard> createState() => _ChangeSecretCardState();
}

class _ChangeSecretCardState extends ConsumerState<ChangeSecretCard> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  String get _word => widget.usesPassword ? 'password' : 'PIN';

  List<TextInputFormatter>? get _formatters => widget.usesPassword
      ? null
      : [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(Validators.pinLength),
        ];

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changed = await ref
        .read(accountControllerProvider.notifier)
        .changeSecret(
          identifier: widget.identifier,
          current: _current.text,
          next: _next.text,
        );
    if (!mounted) return;
    if (!changed) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(accountControllerProvider).error,
        ),
      );
      return;
    }
    for (final controller in [_current, _next, _confirm]) {
      controller.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.usesPassword ? 'Password' : 'PIN'} changed. Use the new '
          'one next time you sign in.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(accountControllerProvider).isLoading;
    final pinOrPassword = widget.usesPassword
        ? Validators.password
        : Validators.pin;
    final keyboard = widget.usesPassword ? null : TextInputType.number;
    return AppCard(
      title: widget.usesPassword ? 'Change password' : 'Change PIN',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              hint: 'Your current $_word',
              label: 'Current $_word',
              controller: _current,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: _formatters,
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your current $_word' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: widget.usesPassword
                  ? 'At least ${Validators.passwordMinLength} characters'
                  : '${Validators.pinLength} digits',
              label: 'New $_word',
              controller: _next,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: _formatters,
              validator: (v) => _current.text.isNotEmpty && v == _current.text
                  ? 'Choose a $_word different from the current one'
                  : pinOrPassword(v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              hint: 'Type the new $_word again',
              label: 'Confirm new $_word',
              controller: _confirm,
              obscureText: true,
              keyboardType: keyboard,
              inputFormatters: _formatters,
              validator: (v) =>
                  v == _next.text ? null : "The ${_word}s don't match",
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Change $_word',
              isLoading: busy,
              onPressed: busy ? null : _change,
            ),
          ],
        ),
      ),
    );
  }
}
