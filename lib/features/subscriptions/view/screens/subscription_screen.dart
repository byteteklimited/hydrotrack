import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/subscription.dart';
import '../../data/providers/subscription_providers.dart';
import '../widgets/subscription_history_list.dart';
import '../widgets/subscription_status_tag.dart';

/// The organization's plan (Owner/Admin): where it stands, the price, how
/// to pay, and — for the owner — past payments. Opening it refreshes the
/// status, so a renewal shows as soon as HydroTrack records it.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _maxContentWidth = 720.0;

  @override
  void initState() {
    super.initState();
    Future(() => ref.invalidate(currentSubscriptionProvider));
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final isOwner = ref.watch(authStateProvider)?.role == StaffRole.owner;

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
                        _HowToPayCard(subscription: subscription),
                        if (isOwner) ...[
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = subscription.monthlyPrice;
    return AppCard(
      title: 'HydroTrack plan',
      accentColor: subscription.canRecord ? null : AppColors.dangerFg,
      trailing: SubscriptionStatusTag(status: subscription.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subscriptionSummary(subscription, DateTime.now()),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            price == null
                ? 'Price: ask HydroTrack'
                : '${formatNaira(price)} a month',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPayCard extends StatelessWidget {
  const _HowToPayCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instructions = subscription.paymentInstructions;
    return AppCard(
      title: 'How to pay',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            instructions ??
                "HydroTrack hasn't added payment details yet. Contact "
                    'HydroTrack to renew.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "After paying, send your receipt with your organization's name. "
            'Your paid time is extended as soon as HydroTrack records the '
            'payment.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
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
