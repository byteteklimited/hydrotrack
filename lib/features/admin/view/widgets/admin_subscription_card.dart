import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../subscriptions/data/models/plan.dart';
import '../../../subscriptions/data/providers/subscription_providers.dart';
import '../../../subscriptions/view/widgets/plan_usage.dart';
import '../../../subscriptions/view/widgets/subscription_status_tag.dart';
import '../../data/models/admin_organization.dart';
import '../../data/providers/admin_providers.dart';
import 'admin_subscription_dialogs.dart';

/// Where the organization's subscription stands, and the admin's actions
/// on it.
class AdminSubscriptionCard extends ConsumerWidget {
  const AdminSubscriptionCard({super.key, required this.organization});

  final AdminOrganization organization;

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final done = await ref
        .read(adminActionControllerProvider.notifier)
        .setSuspended(organizationId: organization.id, suspended: false);
    if (!done && context.mounted) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(adminActionControllerProvider).error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = organization.subscription;
    if (subscription == null) {
      return const AppCard(
        title: 'Subscription',
        child: Text('No subscription found for this organization.'),
      );
    }
    final busy = ref.watch(adminActionControllerProvider).isLoading;
    final plans = ref.watch(plansProvider).valueOrNull ?? const <Plan>[];
    final suspended = subscription.suspendedAt != null;
    final requested = subscription.requestedPlanKey;
    final theme = Theme.of(context);

    return AppCard(
      title: 'Subscription',
      accentColor: subscription.canRecord ? null : AppColors.dangerFg,
      trailing: SubscriptionStatusTag(status: subscription.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subscription.plan != null)
            Text(
              '${subscription.plan!.name} plan',
              style: theme.textTheme.titleSmall,
            ),
          Text(subscriptionSummary(subscription, DateTime.now())),
          for (final line in planUsageLines(subscription))
            Text(
              line.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: line.over ? AppColors.dangerFg : AppColors.textSecondary,
              ),
            ),
          if (requested != null)
            Text(
              'Owner chose ${toTitleCase(requested)}: record their payment '
              'to move them to it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.warningFg,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Record payment',
                leadingIcon: Icons.payments_outlined,
                onPressed: busy || plans.isEmpty
                    ? null
                    : () =>
                          showRecordPaymentDialog(context, organization, plans),
              ),
              AppButton(
                label: 'Change plan',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.swap_horiz,
                onPressed: busy || plans.isEmpty
                    ? null
                    : () => showChangePlanDialog(context, organization, plans),
              ),
              AppButton(
                label: 'Give free days',
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.card_giftcard_outlined,
                onPressed: busy
                    ? null
                    : () => showFreeDaysDialog(context, organization),
              ),
              suspended
                  ? AppButton(
                      label: 'Resume',
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.play_arrow_outlined,
                      isLoading: busy,
                      onPressed: busy ? null : () => _resume(context, ref),
                    )
                  : AppButton(
                      label: 'Suspend',
                      variant: AppButtonVariant.destructive,
                      leadingIcon: Icons.block,
                      onPressed: busy
                          ? null
                          : () => showSuspendDialog(context, organization),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
