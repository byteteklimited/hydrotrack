import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';

/// "Choose a PIN" + "Confirm PIN" (6 digits each, must match), shared by
/// joining with an invite and resetting a PIN.
class NewPinFields extends StatelessWidget {
  const NewPinFields({
    super.key,
    required this.pinController,
    required this.confirmController,
    this.label = 'Choose a PIN',
  });

  final TextEditingController pinController;
  final TextEditingController confirmController;
  final String label;

  static final _formatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(Validators.pinLength),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          hint: '6 digits',
          label: label,
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: _formatters,
          helperText: "You'll sign in with your phone number and this PIN",
          validator: Validators.pin,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          hint: 'Type the PIN again',
          label: 'Confirm PIN',
          controller: confirmController,
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: _formatters,
          validator: (value) =>
              value == pinController.text ? null : "PINs don't match",
        ),
      ],
    );
  }
}
