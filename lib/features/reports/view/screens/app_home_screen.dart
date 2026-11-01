import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_nav_section.dart';
import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../debts/view/screens/customers_directory_screen.dart';
import '../../../debts/view/screens/debts_screen.dart';
import '../../../distribution/view/screens/distribution_screen.dart';
import '../../../expenses/view/screens/expenses_screen.dart';
import '../../../finance/view/screens/finance_screen.dart';
import '../../../inventory/view/screens/inventory_screen.dart';
import '../../../machines/view/screens/machines_screen.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../organizations/view/screens/organization_settings_screen.dart';
import '../../../payroll/view/screens/workers_screen.dart';
import '../../../production/view/screens/production_list_screen.dart';
import '../../../products/view/screens/products_screen.dart';
import '../../../purchases/view/screens/purchases_screen.dart';
import '../../../quality/view/screens/quality_screen.dart';
import '../../../sales/view/screens/sales_list_screen.dart';
import '../../../staff/view/screens/staff_screen.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';

/// Composition root for everything behind sign-in: wires the adaptive
/// navigation shell to every feature's screen.
///
/// Renders nothing while there's no signed-in member or organization (the
/// moment between signing out and leaving this screen), so no feature
/// screen ever builds without an organization to load.
class AppHomeScreen extends ConsumerWidget {
  const AppHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signs someone who got in offline back in online once connected.
    ref.watch(onlineSessionRestorerProvider);
    final hasMember = ref.watch(authStateProvider) != null;
    final hasOrganization = ref.watch(currentOrganizationProvider) != null;
    if (!hasMember || !hasOrganization) return const Scaffold();
    // Every screen works in a location: wait until it's known.
    return ref
        .watch(locationOptionsProvider)
        .when(
          loading: () => const Scaffold(body: AppLoading()),
          error: (error, stackTrace) => Scaffold(
            body: AppErrorState(
              message:
                  readableErrorMessage(error) ??
                  "Couldn't load your locations. Check your connection and "
                      'try again.',
              onRetry: () => ref.invalidate(locationOptionsProvider),
            ),
          ),
          data: (options) => options.allowed.isEmpty
              ? const Scaffold(
                  body: AppEmptyState(
                    icon: Icons.place_outlined,
                    title: "You aren't assigned to a location",
                    message:
                        'Ask the owner to add you to a factory or depot under '
                        'Organization → Locations, then open the app again.',
                  ),
                )
              : AppNavigationShell(pageBuilder: _buildPage),
        );
  }

  static Widget _buildPage(AppSection section) {
    return switch (section) {
      AppSection.home => const DashboardScreen(),
      AppSection.production => const ProductionListScreen(),
      AppSection.inventory => const InventoryScreen(),
      AppSection.sales => const SalesListScreen(),
      AppSection.debts => const DebtsScreen(),
      AppSection.customers => const CustomersDirectoryScreen(),
      AppSection.finance => const FinanceScreen(),
      AppSection.distribution => const DistributionScreen(),
      AppSection.expenses => const ExpensesScreen(),
      AppSection.purchases => const PurchasesScreen(),
      AppSection.machines => const MachinesScreen(),
      AppSection.quality => const QualityScreen(),
      AppSection.workers => const WorkersScreen(),
      AppSection.reports => const ReportsScreen(),
      AppSection.staff => const StaffScreen(),
      AppSection.products => const ProductsScreen(),
      AppSection.organization => const OrganizationSettingsScreen(),
    };
  }
}
