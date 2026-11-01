import 'package:flutter/material.dart';

import '../../features/auth/data/models/staff_user.dart';

/// Every navigable area of the app, whether or not its screen is built yet.
enum AppSection {
  home,
  production,
  inventory,
  sales,
  debts,
  customers,
  finance,
  distribution,
  expenses,
  purchases,
  reports,
  staff,
  products,
  organization,
}

extension AppSectionMeta on AppSection {
  String get label => switch (this) {
    AppSection.home => 'Home',
    AppSection.production => 'Production',
    AppSection.inventory => 'Inventory',
    AppSection.sales => 'Sales',
    AppSection.debts => 'Debts',
    AppSection.customers => 'Customers',
    AppSection.finance => 'Finance',
    AppSection.distribution => 'Distribution',
    AppSection.expenses => 'Expenses',
    AppSection.purchases => 'Purchases',
    AppSection.reports => 'Reports',
    AppSection.staff => 'Staff',
    AppSection.products => 'Products & prices',
    AppSection.organization => 'Organization',
  };

  IconData get icon => switch (this) {
    AppSection.home => Icons.home_outlined,
    AppSection.production => Icons.factory_outlined,
    AppSection.inventory => Icons.inventory_2_outlined,
    AppSection.sales => Icons.point_of_sale_outlined,
    AppSection.debts => Icons.receipt_long_outlined,
    AppSection.customers => Icons.people_outline,
    AppSection.finance => Icons.account_balance_outlined,
    AppSection.distribution => Icons.local_shipping_outlined,
    AppSection.expenses => Icons.payments_outlined,
    AppSection.purchases => Icons.shopping_cart_outlined,
    AppSection.reports => Icons.bar_chart_outlined,
    AppSection.staff => Icons.badge_outlined,
    AppSection.products => Icons.sell_outlined,
    AppSection.organization => Icons.business_outlined,
  };
}

/// A role's primary nav destinations, plus whatever overflows into "More".
/// An empty [overflow] means no More destination is shown at all.
class RoleNavConfig {
  const RoleNavConfig({required this.primary, required this.overflow});

  final List<AppSection> primary;
  final List<AppSection> overflow;

  static const _managementPrimary = [
    AppSection.home,
    AppSection.production,
    AppSection.inventory,
    AppSection.sales,
    AppSection.debts,
  ];

  static const _managementOverflow = [
    AppSection.customers,
    AppSection.finance,
    AppSection.distribution,
    AppSection.expenses,
    AppSection.purchases,
    AppSection.reports,
    AppSection.staff,
  ];

  factory RoleNavConfig.forRole(StaffRole role) {
    return switch (role) {
      StaffRole.cashier => const RoleNavConfig(
        primary: [AppSection.home, AppSection.sales, AppSection.debts],
        overflow: [],
      ),
      StaffRole.storeKeeper => const RoleNavConfig(
        primary: [
          AppSection.home,
          AppSection.production,
          AppSection.inventory,
          AppSection.distribution,
          AppSection.purchases,
        ],
        overflow: [],
      ),
      StaffRole.owner || StaffRole.admin => const RoleNavConfig(
        primary: _managementPrimary,
        overflow: [
          ..._managementOverflow,
          AppSection.products,
          AppSection.organization,
        ],
      ),
      StaffRole.manager => const RoleNavConfig(
        primary: _managementPrimary,
        overflow: _managementOverflow,
      ),
    };
  }
}
