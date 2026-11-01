import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_modal.dart';
import '../screens/cash_count_screen.dart';

/// Home, for people who take cash: a reminder and button to count at the
/// end of the shift.
class CountCashCard extends StatelessWidget {
  const CountCashCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'End of your shift? Count the cash you took.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AppButton(
              label: 'Count cash',
              variant: AppButtonVariant.secondary,
              onPressed: () => showAppModal<void>(
                context,
                builder: (_) => const CashCountScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
