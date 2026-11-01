import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
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
    final suspended = subscription.suspendedAt != null;

    return AppCard(
      title: 'Subscription',
      accentColor: subscription.canRecord ? null : AppColors.dangerFg,
      trailing: SubscriptionStatusTag(status: subscription.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subscriptionSummary(subscription, DateTime.now())),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Record payment',
                leadingIcon: Icons.payments_outlined,
                onPressed: busy
                    ? null
                    : () => showRecordPaymentDialog(context, organization),
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
