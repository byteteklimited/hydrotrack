import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/subscription_event.dart';
import 'subscription_status_tag.dart';

/// Payments, free days, plan changes and suspensions, newest first. Used on the owner's
/// subscription screen and in the admin console.
class SubscriptionHistoryList extends StatelessWidget {
  const SubscriptionHistoryList({
    super.key,
    required this.events,
    required this.emptyMessage,
  });

  final List<SubscriptionEvent> events;
  final String emptyMessage;

  static String describe(SubscriptionEvent event) {
    String plural(int count, String unit) =>
        count == 1 ? '1 $unit' : '$count ${unit}s';
    final until = event.endsAt == null
        ? ''
        : ' · until ${formatSubscriptionDate(event.endsAt!)}';
    final plan = event.planKey == null ? '' : toTitleCase(event.planKey!);
    return switch (event.kind) {
      SubscriptionEventKind.payment =>
        '${plan.isEmpty ? '' : '$plan · '}${formatNaira(event.amount ?? 0)} '
            'for ${plural(event.months ?? 0, 'month')}$until',
      SubscriptionEventKind.planChanged => 'Plan changed to $plan',
      SubscriptionEventKind.freeDays =>
        '${plural(event.days ?? 0, 'free day')}$until',
      SubscriptionEventKind.suspended => 'Suspended',
      SubscriptionEventKind.resumed => 'Resumed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return Text(
        emptyMessage,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(describe(event), style: theme.textTheme.bodyMedium),
                Text(
                  [
                    formatSubscriptionDate(event.createdAt),
                    if (event.note != null) event.note!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
