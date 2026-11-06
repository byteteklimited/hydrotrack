import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/subscription.dart';
import '../../data/providers/subscription_providers.dart';
import '../widgets/how_to_pay_card.dart';
import '../widgets/plan_choices.dart';
import '../widgets/plan_usage.dart';
import '../widgets/subscription_history_list.dart';
import '../widgets/subscription_status_tag.dart';

/// The organization's plan (Owner/Admin): where it stands, the three
/// plans to choose from, how to pay, and — for the owner — past payments.
/// Opening it refreshes the status, so a renewal shows as soon as
/// HydroTrack records it.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _maxContentWidth = 1040.0;

  @override
  void initState() {
    super.initState();
    Future(() => ref.invalidate(currentSubscriptionProvider));
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final role = ref.watch(authStateProvider)?.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subscriptionAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => _LoadError(error: error),
        data: (subscription) => subscription == null
            ? const _LoadError()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  ResponsiveCenter(
                    maxWidth: _maxContentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusCard(subscription: subscription),
                        const SizedBox(height: AppSpacing.lg),
                        PlanChoices(
                          subscription: subscription,
                          canChoose: role?.isAdminLevel ?? false,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        HowToPayCard(subscription: subscription),
                        if (role == StaffRole.owner) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _HistoryCard(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppErrorState(
    message:
        readableErrorMessage(error) ??
        "Couldn't load the subscription. Check your connection and try again.",
    onRetry: () => ref.invalidate(currentSubscriptionProvider),
  );
}

/// The plan, where it stands, and how much of it is in use.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = subscription.plan;
    return AppCard(
      title: plan == null ? 'Your plan' : '${plan.name} plan',
      accentColor: subscription.canRecord ? null : AppColors.dangerFg,
      trailing: SubscriptionStatusTag(status: subscription.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subscriptionSummary(subscription, DateTime.now()),
            style: theme.textTheme.bodyLarge,
          ),
          if (plan != null) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final line in planUsageLines(subscription))
              Text(
                line.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: line.over
                      ? AppColors.dangerFg
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(subscriptionHistoryProvider);
    return AppCard(
      title: 'Payments',
      child: historyAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => Text(
          readableErrorMessage(error) ??
              "Couldn't load payments. Check your connection.",
        ),
        data: (events) => SubscriptionHistoryList(
          events: events,
          emptyMessage: 'No payments recorded yet.',
        ),
      ),
    );
  }
}
