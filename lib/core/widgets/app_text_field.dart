import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// The app's standard form input. The box itself (outline, radius, focus
/// ring) comes entirely from `InputDecorationTheme`; this widget owns the
/// label-above-the-box layout and the few per-field extras (unit suffix,
/// show/hide for an obscured field) that theme can't express.
///
/// When [obscureText] is true (a PIN or password field), a show/hide
/// toggle is added automatically — every obscured field in the app gets
/// it for free, nothing extra to wire up at the call site.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.helperText,
    this.enabled = true,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;

  /// A unit shown inside the box, after whatever's typed — "bags",
  /// "litres", "kg". Ignored when [obscureText] is true (the show/hide
  /// toggle already owns the suffix slot there).
  final String? suffixText;
  final String? helperText;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  /// More than 1 for free text such as instructions or notes.
  final int maxLines;

  /// ₦ amount field — digits only, with live thousands-grouping.
  factory AppTextField.naira({
    Key? key,
    required String label,
    TextEditingController? controller,
    FormFieldValidator<String>? validator,
    String? helperText,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      validator: validator,
      helperText: helperText,
      enabled: enabled,
      keyboardType: TextInputType.number,
      prefixText: '₦ ',
      inputFormatters: [ThousandsInputFormatter()],
    );
  }

  /// Whole-number quantity field — bags, rolls, cartons. Pass [unit] to
  /// show it inside the box (e.g. "bags") rather than only in the label.
  factory AppTextField.quantity({
    Key? key,
    required String label,
    TextEditingController? controller,
    FormFieldValidator<String>? validator,
    String? helperText,
    String? unit,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      validator: validator,
      helperText: helperText,
      enabled: enabled,
      keyboardType: TextInputType.number,
      suffixText: unit,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  /// A positive decimal measurement — litres, kilograms, a recipe
  /// ratio's "quantity used" — where a whole number alone (`.quantity`)
  /// would be too blunt.
  factory AppTextField.decimal({
    Key? key,
    required String label,
    TextEditingController? controller,
    FormFieldValidator<String>? validator,
    String? helperText,
    String? unit,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      validator: validator,
      helperText: helperText,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffixText: unit,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
    );
  }

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.obscureText && _obscured,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          decoration: InputDecoration(
            helperText: widget.helperText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscured ? 'Show' : 'Hide',
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.suffixIcon,
            prefixText: widget.prefixText,
            suffixText: widget.obscureText ? null : widget.suffixText,
          ),
        ),
      ],
    );
  }
}
