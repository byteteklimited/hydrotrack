import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/models/subscription.dart';

extension SubscriptionStatusColor on SubscriptionStatus {
  Color get color => switch (this) {
    SubscriptionStatus.trial => AppColors.textSecondary,
    SubscriptionStatus.active => AppColors.successFg,
    SubscriptionStatus.grace => AppColors.warningFg,
    SubscriptionStatus.expired ||
    SubscriptionStatus.suspended => AppColors.dangerFg,
  };
}

String formatSubscriptionDate(DateTime date) =>
    DateFormat('d MMM y').format(date.toLocal());

/// One line saying where the subscription stands, e.g. "Free trial ends
/// 15 Nov 2026 (3 days left)".
String subscriptionSummary(Subscription subscription, DateTime now) {
  String daysLeft(DateTime until) {
    final days = Subscription.daysUntil(until, now);
    return days == 1 ? '1 day left' : '$days days left';
  }

  return switch (subscription.status) {
    SubscriptionStatus.trial =>
      'Free trial ends ${formatSubscriptionDate(subscription.endsAt)} '
          '(${daysLeft(subscription.endsAt)})',
    SubscriptionStatus.active =>
      'Paid until ${formatSubscriptionDate(subscription.endsAt)}',
    SubscriptionStatus.grace =>
      'Ended ${formatSubscriptionDate(subscription.endsAt)}. Recording stops '
          '${formatSubscriptionDate(subscription.accessEndsAt)} '
          '(${daysLeft(subscription.accessEndsAt)}) unless it is renewed',
    SubscriptionStatus.expired =>
      'Ended ${formatSubscriptionDate(subscription.endsAt)}. Records can be '
          'viewed and exported, but nothing new can be recorded until it is '
          'renewed',
    SubscriptionStatus.suspended =>
      'Suspended: ${subscription.suspendedReason ?? 'no reason given'}',
  };
}

class SubscriptionStatusTag extends StatelessWidget {
  const SubscriptionStatusTag({super.key, required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) =>
      AppStatusTag(label: status.label, color: status.color);
}
