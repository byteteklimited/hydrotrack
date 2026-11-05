import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/organization_providers.dart';

/// A one-field form shown with `showAppModal`: "Create organization",
/// "Join with invite code" and "Rename organization" all share it.
/// [onSubmit] runs the action through [organizationActionControllerProvider]
/// and returns the value to pop with (null when it failed — the
/// controller's error is then shown inline).
class SingleFieldActionScreen<T> extends ConsumerStatefulWidget {
  const SingleFieldActionScreen({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
    required this.submitLabel,
    required this.emptyMessage,
    required this.onSubmit,
    this.helperText,
    this.initialValue,
  });

  final String title;
  final String fieldLabel;
  final String fieldHint;
  final String submitLabel;

  /// Shown under the field when it's left blank.
  final String emptyMessage;
  final String? helperText;
  final String? initialValue;
  final Future<T?> Function(WidgetRef ref, String value) onSubmit;

  @override
  ConsumerState<SingleFieldActionScreen<T>> createState() =>
      _SingleFieldActionScreenState<T>();
}

class _SingleFieldActionScreenState<T>
    extends ConsumerState<SingleFieldActionScreen<T>> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue);

  static const _maxFormWidth = 520.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = await widget.onSubmit(ref, _controller.text.trim());
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationActionControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't save — check your connection and try again."
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsiveCenter(
          maxWidth: _maxFormWidth,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  hint: widget.fieldHint,
                  label: widget.fieldLabel,
                  controller: _controller,
                  helperText: widget.helperText,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? widget.emptyMessage
                      : null,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInlineAlert(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: widget.submitLabel,
                  onPressed: state.isLoading ? null : _submit,
                  isLoading: state.isLoading,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
