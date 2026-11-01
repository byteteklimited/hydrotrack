import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/action_error.dart';
import 'app_button.dart';

/// A small form in a dialog: validates [formKey], runs [onSubmit], closes
/// when it succeeds, otherwise shows the reason from [error].
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.formKey,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.fields,
    required this.busy,
    required this.error,
    this.intro,
    this.destructive = false,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? intro;
  final String submitLabel;

  /// True when it worked.
  final Future<bool> Function() onSubmit;

  /// The failure behind a false [onSubmit], for its message.
  final Object? Function() error;
  final List<Widget> fields;
  final bool busy;
  final bool destructive;

  Future<void> _submit(BuildContext context) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final done = await onSubmit();
    if (!context.mounted) return;
    if (!done) {
      showActionErrorSnackBar(context, message: readableErrorMessage(error()));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (intro != null)
                Text(
                  intro!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              for (final (index, field) in fields.indexed) ...[
                if (index > 0 || intro != null)
                  const SizedBox(height: AppSpacing.md),
                field,
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: submitLabel,
          variant: destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          isLoading: busy,
          onPressed: busy ? null : () => _submit(context),
        ),
      ],
    );
  }
}
