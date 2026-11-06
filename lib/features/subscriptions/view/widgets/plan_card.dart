import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/plan.dart';

/// One plan on the Subscription screen: price, who it's for, what's
/// included, and where the organization stands with it.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrent,
    required this.isChosen,
    this.onChoose,
    this.busy = false,
  });

  final Plan plan;

  /// The plan the organization is on now.
  final bool isCurrent;

  /// Chosen by the owner, waiting for payment.
  final bool isChosen;

  /// Null when the person can't choose (not Owner/Admin).
  final VoidCallback? onChoose;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    return AppCard(
      title: plan.name,
      accentColor: plan.isPopular ? brand.primary : null,
      trailing: plan.isPopular
          ? AppStatusTag(label: 'Most popular', color: brand.primaryText)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatNaira(plan.monthlyPrice),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' a month',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final line in [
            'All features',
            plan.staffLimit,
            plan.locationLimit,
          ])
            _Included(text: line),
          const SizedBox(height: AppSpacing.md),
          _Footer(
            plan: plan,
            isCurrent: isCurrent,
            isChosen: isChosen,
            onChoose: onChoose,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

class _Included extends StatelessWidget {
  const _Included({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
    child: Row(
      children: [
        const Icon(Icons.check, size: 18, color: AppColors.successFg),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.plan,
    required this.isCurrent,
    required this.isChosen,
    required this.onChoose,
    required this.busy,
  });

  final Plan plan;
  final bool isCurrent;
  final bool isChosen;
  final VoidCallback? onChoose;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (isChosen) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: AppStatusTag(
          label: 'Chosen · waiting for payment',
          color: AppColors.warningFg,
        ),
      );
    }
    if (isCurrent && onChoose == null) {
      return const AppStatusTag(label: 'Your plan', color: AppColors.successFg);
    }
    if (onChoose == null) return const SizedBox.shrink();
    final button = AppButton(
      label: isCurrent ? 'Keep ${plan.name}' : 'Choose ${plan.name}',
      variant: plan.isPopular
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
      isLoading: busy,
      onPressed: onChoose,
    );
    if (!isCurrent) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: AppStatusTag(label: 'Your plan', color: AppColors.successFg),
        ),
        const SizedBox(height: AppSpacing.sm),
        button,
      ],
    );
  }
}
