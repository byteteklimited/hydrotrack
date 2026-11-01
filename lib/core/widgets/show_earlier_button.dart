import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/date_utils.dart';
import 'app_button.dart';

/// At the end of a list that loads recent history: says how far back it
/// goes and loads [HistoryWindow.stepDays] more days.
class ShowEarlierButton extends StatelessWidget {
  const ShowEarlierButton({
    super.key,
    required this.days,
    required this.onPressed,
  });

  final int days;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Showing the last $days days',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          AppButton(
            label: 'Show ${HistoryWindow.stepDays} more days',
            variant: AppButtonVariant.text,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
