import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card_grid.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/plan.dart';
import '../../data/models/subscription.dart';
import '../../data/providers/subscription_providers.dart';
import 'plan_card.dart';

/// Starter, Standard and Premium side by side. Owners and Admins choose
/// one; it takes effect when HydroTrack records their payment.
class PlanChoices extends ConsumerWidget {
  const PlanChoices({
    super.key,
    required this.subscription,
    required this.canChoose,
  });

  final Subscription subscription;
  final bool canChoose;

  Future<void> _choose(BuildContext context, WidgetRef ref, Plan plan) async {
    final done = await ref
        .read(subscriptionActionControllerProvider.notifier)
        .choosePlan(plan.key);
    if (!context.mounted) return;
    if (!done) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(subscriptionActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${plan.name} chosen. Pay ${formatNaira(plan.monthlyPrice)} to the '
          'account below; your plan changes as soon as HydroTrack records '
          'the payment.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final busy = ref.watch(subscriptionActionControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plans', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          canChoose
              ? 'Every plan has every feature. Choose one, pay, and it starts '
                    'as soon as HydroTrack records your payment.'
              : 'Every plan has every feature. Ask the owner to change plan.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        plansAsync.when(
          loading: () => const AppLoading(),
          error: (error, stackTrace) => Text(
            readableErrorMessage(error) ??
                "Couldn't load the plans. Check your connection and try again.",
          ),
          data: (plans) => AppCardGrid(
            cards: [
              for (final plan in plans)
                PlanCard(
                  plan: plan,
                  isCurrent: plan.key == subscription.plan?.key,
                  isChosen: plan.key == subscription.requestedPlanKey,
                  busy: busy,
                  onChoose: canChoose && !busy
                      ? () => _choose(context, ref, plan)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
