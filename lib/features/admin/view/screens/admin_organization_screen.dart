import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../subscriptions/view/widgets/subscription_history_list.dart';
import '../../data/models/admin_organization.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/admin_organization_details_card.dart';
import '../widgets/admin_subscription_card.dart';

/// One organization in the admin console: contact details, subscription
/// with Record payment / Give free days / Suspend, and its history.
class AdminOrganizationScreen extends ConsumerWidget {
  const AdminOrganizationScreen({super.key, required this.organizationId});

  final String organizationId;

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationsAsync = ref.watch(adminOrganizationsProvider);

    return organizationsAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              readableErrorMessage(error) ??
              "Couldn't load this organization. Check your connection and "
                  'try again.',
          onRetry: () => ref.invalidate(adminOrganizationsProvider),
        ),
      ),
      data: (organizations) {
        final organization = organizations
            .where((organization) => organization.id == organizationId)
            .firstOrNull;
        if (organization == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This organization no longer exists.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(organization.name)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ResponsiveCenter(
                maxWidth: _maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminSubscriptionCard(organization: organization),
                    const SizedBox(height: AppSpacing.lg),
                    AdminOrganizationDetailsCard(organization: organization),
                    const SizedBox(height: AppSpacing.lg),
                    _HistoryCard(organization: organization),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.organization});

  final AdminOrganization organization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(adminHistoryProvider(organization.id));
    return AppCard(
      title: 'History',
      child: historyAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => Text(
          readableErrorMessage(error) ??
              "Couldn't load the history. Check your connection.",
        ),
        data: (events) => SubscriptionHistoryList(
          events: events,
          emptyMessage: 'No payments, free days or suspensions yet.',
        ),
      ),
    );
  }
}
