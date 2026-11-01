import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/alerts_providers.dart';

/// The owner's alerts: daily summaries and low stock. Opening it marks
/// them read.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      try {
        await ref.read(alertsRepositoryProvider).markAllRead();
        ref.invalidate(alertsProvider);
      } catch (_) {
        // Offline: they stay unread until next time.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alertsAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => AppErrorState(
          message:
              readableErrorMessage(error) ??
              "Couldn't load alerts. Check your connection and try again.",
          onRetry: () => ref.invalidate(alertsProvider),
        ),
        data: (alerts) => alerts.isEmpty
            ? const AppEmptyState(
                icon: Icons.notifications_none,
                title: 'No alerts',
                message:
                    'A summary arrives each evening at 8 pm, and an alert '
                    'whenever stock reaches its reorder level.',
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  ResponsiveCenter(
                    maxWidth: 720,
                    child: Column(
                      children: [
                        for (final alert in alerts)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              accentColor: alert.isLowStock
                                  ? AppColors.lowStockWarning
                                  : null,
                              title: alert.title,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alert.body),
                                  Text(
                                    DateFormat(
                                      'd MMM, h:mm a',
                                    ).format(alert.createdAt.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
