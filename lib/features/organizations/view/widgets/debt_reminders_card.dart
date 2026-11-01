import 'package:flutter/material.dart';

import '../../../../core/constants/debts_thresholds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/models/organization.dart';
import '../screens/bank_details_screen.dart';

/// Explains the automatic SMS debt reminders and holds the bank details
/// they print, with a button to add or change them.
class DebtRemindersCard extends StatelessWidget {
  const DebtRemindersCard({super.key, required this.organization});

  final Organization organization;

  static const _schedule =
      'Customers who still owe ${DebtsThresholds.overdueDays} days after '
      'their last payment get an SMS reminder in the morning, then every '
      '${DebtsThresholds.reminderIntervalDays} days while they owe, up to '
      '${DebtsThresholds.maxReminders} times. Any payment starts the count '
      'again.';

  Future<void> _edit(BuildContext context) async {
    final updated = await showAppModal<Organization>(
      context,
      builder: (_) => BankDetailsScreen(organization: organization),
    );
    if (updated != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.bankDetails == null
                ? 'Bank details removed from reminders.'
                : 'Bank details saved. Reminders will include them.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = organization.bankDetails;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return AppCard(
      title: 'Debt reminders',
      trailing: AppButton(
        label: details == null ? 'Add bank details' : 'Edit',
        variant: AppButtonVariant.text,
        onPressed: () => _edit(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_schedule, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          if (details == null)
            Text(
              'No bank details yet: reminders ask customers to pay but '
              "don't say where. Add your account so they can pay by transfer.",
              style: secondary,
            )
          else ...[
            Text('Customers are asked to pay to', style: secondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${details.bankName} · ${details.accountNumber}',
              style: theme.textTheme.titleSmall,
            ),
            Text(details.accountName, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
