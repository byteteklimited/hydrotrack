import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_nav_section.dart';
import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../debts/view/screens/customers_directory_screen.dart';
import '../../../debts/view/screens/debts_screen.dart';
import '../../../distribution/view/screens/distribution_screen.dart';
import '../../../expenses/view/screens/expenses_screen.dart';
import '../../../finance/view/screens/finance_screen.dart';
import '../../../inventory/view/screens/inventory_screen.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../../organizations/view/screens/organization_settings_screen.dart';
import '../../../production/view/screens/production_list_screen.dart';
import '../../../products/view/screens/products_screen.dart';
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
    return AppNavigationShell(pageBuilder: _buildPage);
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
      AppSection.reports => const ReportsScreen(),
      AppSection.staff => const StaffScreen(),
      AppSection.products => const ProductsScreen(),
      AppSection.organization => const OrganizationSettingsScreen(),
    };
  }
}
