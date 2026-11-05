import 'package:flutter/material.dart';

import '../../../../core/constants/payment_channel.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/sale.dart';

/// Payment method, amount paid, and the outstanding-balance callout when
/// the sale isn't fully paid. A part payment also needs its own channel
/// — unlike a plain cash/transfer sale, the method itself ("Part
/// payment") doesn't say how the paid portion actually came in, and
/// without it that amount could never post to Finance's cash ledger.
class SalePaymentSection extends StatelessWidget {
  const SalePaymentSection({
    super.key,
    required this.paymentMethod,
    required this.amountPaidController,
    required this.balance,
    required this.customerLabel,
    required this.onMethodChanged,
    required this.paidChannel,
    required this.onPaidChannelChanged,
  });

  final PaymentMethod paymentMethod;
  final TextEditingController amountPaidController;
  final num balance;
  final String customerLabel;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final PaymentChannel paidChannel;
  final ValueChanged<PaymentChannel> onPaidChannelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppDropdownField<PaymentMethod>(
          label: 'Payment method',
          value: paymentMethod,
          items: PaymentMethod.values,
          itemLabel: (method) => method.label,
          onChanged: (method) => onMethodChanged(method!),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField.naira(
          hint: 'e.g. 6,000',
          label: 'Amount paid',
          controller: amountPaidController,
          enabled: paymentMethod == PaymentMethod.part,
        ),
        if (paymentMethod == PaymentMethod.part) ...[
          const SizedBox(height: AppSpacing.md),
          AppDropdownField<PaymentChannel>(
            label: 'How was the paid amount received?',
            value: paidChannel,
            items: PaymentChannel.values,
            itemLabel: (channel) => channel.label,
            onChanged: (channel) => onPaidChannelChanged(channel!),
          ),
        ],
        if (balance > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            "${formatNaira(balance)} will be added to $customerLabel's balance.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
