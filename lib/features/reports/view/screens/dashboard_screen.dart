import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../../core/widgets/app_stat_strip.dart';
import '../../../../core/widgets/app_stat_tile.dart';
import '../../../../core/widgets/app_stat_tile_grid.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../debts/view/screens/debts_screen.dart';
import '../../../finance/view/widgets/count_cash_card.dart';
import '../../../offline/view/widgets/needs_checking_card.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../organizations/view/widgets/account_menu_button.dart';
import '../../../organizations/view/widgets/setup_checklist_card.dart';
import '../../data/providers/dashboard_providers.dart';
import '../widgets/dashboard_activity_card.dart';
import '../widgets/dashboard_cash_flow_chart.dart';
import '../widgets/dashboard_last_payment_card.dart';
import '../widgets/dashboard_low_stock_card.dart';

/// Same reasoning as every other screen in the app: content reads best
/// at a bounded width, implemented as responsive padding so `ListView`
/// keeps its native scroll behavior. Wider than the usual 900/1200 caps
/// — this screen's headline stat strip and chart genuinely use the
/// extra room on a big desktop window.
const double _contentCap = 1280;

/// Home tab: a headline stat strip (today's production/cash, revenue,
/// money outside), a compact secondary row, a 7-day cash-flow chart,
/// last payment, low stock (if any), then a daily activity feed.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const double _maxStatTileWidth = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(dashboardSnapshotProvider);
    final user = ref.watch(authStateProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final hasSidebar = MediaQuery.sizeOf(context).width >= wideNavBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        // On phones there's no sidebar footer, so the account menu
        // (organization, switch, sign out) lives here.
        actions: [if (!hasSidebar) const AccountMenuButton()],
      ),
      body: snapshotAsync.when(
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardSnapshotProvider.future),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;
              final hasOverdue = snapshot.overdueCustomerCount > 0;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  Text(
                    [
                      ?organization?.name,
                      DateFormat('EEE, d MMM').format(DateTime.now()),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _greeting(user),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (user?.role == StaffRole.owner) const SetupChecklistCard(),
                  if (user != null &&
                      const [
                        StaffRole.admin,
                        StaffRole.manager,
                        StaffRole.cashier,
                      ].contains(user.role))
                    const CountCashCard(),
                  if (user?.role.canManage ?? false) const NeedsCheckingCard(),
                  AppStatStrip(
                    items: [
                      AppStatStripItem(
                        label: 'Bags produced today',
                        value: NumberFormat.decimalPattern(
                          'en_NG',
                        ).format(snapshot.bagsProducedToday),
                      ),
                      AppStatStripItem(
                        label: 'Cash collected today',
                        value: formatNaira(snapshot.cashCollectedToday),
                      ),
                      AppStatStripItem(
                        label: 'Total revenue',
                        value: formatNaira(snapshot.totalRevenue),
                        qualifier: 'All-time sales',
                      ),
                      AppStatStripItem(
                        label: 'Money outside',
                        value: formatNaira(snapshot.moneyOutside),
                        valueColor: hasOverdue ? AppColors.moneyOut : null,
                        qualifier: hasOverdue
                            ? '${snapshot.overdueCustomerCount} overdue'
                            : 'All accounts current',
                        onTap: () => showAppModal(
                          context,
                          builder: (_) => const DebtsScreen(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppStatTileGrid(
                    maxTileWidth: _maxStatTileWidth,
                    tiles: [
                      AppStatTile(
                        icon: Icons.groups_outlined,
                        label: 'Total customers',
                        value: NumberFormat.decimalPattern(
                          'en_NG',
                        ).format(snapshot.totalCustomers),
                      ),
                      AppStatTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'Total bags produced',
                        value: NumberFormat.decimalPattern(
                          'en_NG',
                        ).format(snapshot.totalBagsProduced),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DashboardCashFlowChart(days: snapshot.cashFlow),
                  const SizedBox(height: AppSpacing.md),
                  DashboardLastPaymentCard(payment: snapshot.lastPayment),
                  if (snapshot.lowStock != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    DashboardLowStockCard(alert: snapshot.lowStock!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  DashboardActivityCard(entries: snapshot.recentActivity),
                ],
              );
            },
          ),
        ),
        loading: () => const AppLoading(message: "Loading today's numbers…"),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load today's numbers. Check your connection and try again.",
          onRetry: () => ref.invalidate(dashboardSnapshotProvider),
        ),
      ),
    );
  }

  String _greeting(StaffUser user) {
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? 'morning'
        : (hour < 17 ? 'afternoon' : 'evening');
    final firstName = user.fullName.split(' ').first;
    return 'Good $period, $firstName';
  }
}
