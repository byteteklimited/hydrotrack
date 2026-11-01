import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/connectivity.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../offline/view/widgets/offline_banner.dart';
import '../../data/models/subscription.dart';
import '../../data/providers/subscription_providers.dart';
import 'subscription_status_tag.dart';

/// Slim app-wide strip when the subscription needs attention: read-only
/// (everyone), or payment due / trial ending soon (Owner and Admin, who
/// can tap through to renew). Hidden otherwise.
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key, required this.onOpenSubscription});

  final VoidCallback onOpenSubscription;

  /// How early owners are reminded that the trial is ending.
  static const trialReminderDays = 3;

  static String? message({
    required Subscription subscription,
    required bool canManage,
    required DateTime now,
  }) {
    final renew = canManage ? ' Tap to renew.' : ' Ask the owner to renew.';
    return switch (subscription.status) {
      SubscriptionStatus.expired =>
        'Subscription ended · read-only, nothing new can be recorded.$renew',
      SubscriptionStatus.suspended =>
        'Suspended by HydroTrack · read-only. '
                '${subscription.suspendedReason ?? ''}'
            .trim(),
      SubscriptionStatus.grace when canManage =>
        'Payment due · recording stops '
            '${formatSubscriptionDate(subscription.accessEndsAt)}.$renew',
      SubscriptionStatus.trial
          when canManage &&
              Subscription.daysUntil(subscription.endsAt, now) <=
                  trialReminderDays =>
        'Free trial ends ${formatSubscriptionDate(subscription.endsAt)}.$renew',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    final role = ref.watch(authStateProvider)?.role;
    if (subscription == null || role == null) return const SizedBox.shrink();
    final canManage = role.isAdminLevel;
    final text = message(
      subscription: subscription,
      canManage: canManage,
      now: DateTime.now(),
    );
    if (text == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final readOnly = !subscription.canRecord;
    // The offline banner above already clears the status bar.
    final belowOfflineBanner =
        OfflineBanner.message(
          isConnected: ref.watch(isConnectedProvider).valueOrNull ?? true,
          offline: ref.watch(offlineControllerProvider),
        ) !=
        null;
    final foreground = readOnly ? AppColors.dangerFg : AppColors.warningFg;

    return Material(
      color: readOnly ? AppColors.dangerBg : AppColors.warningBg,
      child: InkWell(
        onTap: canManage ? onOpenSubscription : null,
        child: SafeArea(
          top: !belowOfflineBanner,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  readOnly ? Icons.lock_outline : Icons.schedule,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
