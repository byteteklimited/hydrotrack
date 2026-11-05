import 'package:flutter/material.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';

/// A cost and how it was paid; the server posts it as an expense.
class CostPaidByFields extends StatelessWidget {
  const CostPaidByFields({
    super.key,
    required this.label,
    required this.cost,
    required this.channel,
    required this.onChannelChanged,
    this.required = false,
    this.helperText,
  });

  final String label;
  final TextEditingController cost;
  final PaymentChannel channel;
  final ValueChanged<PaymentChannel> onChannelChanged;

  /// When false an empty cost means nothing was spent.
  final bool required;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField.naira(
          hint: 'e.g. 15,000',
          label: label,
          controller: cost,
          helperText: helperText,
          validator: required
              ? (v) => (v ?? '').trim().isEmpty ? 'Enter the cost' : null
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppDropdownField<PaymentChannel>(
          label: 'Paid by',
          value: channel,
          items: PaymentChannel.values,
          itemLabel: (c) => c.label,
          onChanged: (c) => onChannelChanged(c!),
        ),
      ],
    );
  }

  /// The typed cost (0 when empty).
  static num read(TextEditingController cost) => parseNairaText(cost.text);
}
