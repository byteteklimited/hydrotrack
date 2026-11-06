import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/providers/subscription_providers.dart';
import '../screens/subscription_screen.dart';
import 'subscription_status_tag.dart';

/// Organization settings: where the subscription stands, and a way to the
/// full Subscription screen (plans, how to pay, payments).
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    if (subscription == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        title: 'Subscription',
        trailing: SubscriptionStatusTag(status: subscription.status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (subscription.plan != null)
              Text(
                '${subscription.plan!.name} plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            Text(subscriptionSummary(subscription, DateTime.now())),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Plans and how to pay',
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.receipt_long_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
