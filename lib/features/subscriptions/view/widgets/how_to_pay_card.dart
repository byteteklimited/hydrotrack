import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/subscription.dart';
import 'bank_account_details.dart';

/// How much to pay and where: HydroTrack's bank account, set in the admin
/// console.
class HowToPayCard extends StatelessWidget {
  const HowToPayCard({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = subscription.bankAccount;
    final instructions = subscription.paymentInstructions;
    final plan = subscription.plan;
    final chosen = subscription.requestedPlanKey;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return AppCard(
      title: 'How to pay',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan != null && chosen == null)
            Text(
              'Your plan: ${plan.name}, ${formatNaira(plan.monthlyPrice)} a '
              'month. To change plan, choose one above first.',
              style: theme.textTheme.bodyMedium,
            ),
          if (chosen != null)
            Text(
              'Pay the price of the plan you chose (${toTitleCase(chosen)}) '
              'for each month.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.sm),
          if (account == null)
            Text(
              "HydroTrack hasn't added payment details yet. Contact HydroTrack "
              'to pay.',
              style: theme.textTheme.bodyMedium,
            )
          else
            BankAccountDetails(account: account),
          if (instructions != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(instructions, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Use your organization's name as the transfer narration. Your "
            'paid time is extended as soon as HydroTrack records the payment.',
            style: muted,
          ),
        ],
      ),
    );
  }
}
