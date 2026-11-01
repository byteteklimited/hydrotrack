import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../subscriptions/data/models/subscription.dart';
import '../../data/models/admin_organization.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/admin_organization_filters.dart';
import '../widgets/admin_organization_tile.dart';
import 'admin_organization_screen.dart';
import 'platform_settings_screen.dart';

/// HydroTrack admin console: every organization with its subscription,
/// searchable and filterable by status. Platform admins only (the server
/// refuses everyone else).
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  static const _maxContentWidth = 840.0;

  String _query = '';
  SubscriptionStatus? _status;

  List<AdminOrganization> _visible(List<AdminOrganization> organizations) => [
    for (final organization in organizations)
      if (organization.matches(_query) &&
          (_status == null || organization.subscription?.status == _status))
        organization,
  ];

  void _open(AdminOrganization organization) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminOrganizationScreen(organizationId: organization.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(adminOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HydroTrack admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Plan and price',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlatformSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: organizationsAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => AppErrorState(
          message:
              readableErrorMessage(error) ??
              "Couldn't load organizations. Check your connection and try "
                  'again.',
          onRetry: () => ref.invalidate(adminOrganizationsProvider),
        ),
        data: (organizations) {
          final visible = _visible(organizations);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(adminOrganizationsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ResponsiveCenter(
                  maxWidth: _maxContentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminOrganizationFilters(
                        organizations: organizations,
                        status: _status,
                        onQueryChanged: (query) =>
                            setState(() => _query = query),
                        onStatusChanged: (status) =>
                            setState(() => _status = status),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (visible.isEmpty)
                        const AppEmptyState(
                          icon: Icons.search_off,
                          title: 'No organizations match',
                          message:
                              'Clear the search or pick another status to see '
                              'more.',
                          compact: true,
                        ),
                      for (final organization in visible)
                        AdminOrganizationTile(
                          organization: organization,
                          onTap: () => _open(organization),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
