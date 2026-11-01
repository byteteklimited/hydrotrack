import 'package:flutter/material.dart';

import '../../../debts/data/models/recent_payment.dart';

export '../../../debts/data/models/recent_payment.dart';

/// One day's money in vs money out — a point on the dashboard's cash-flow
/// chart.
class CashFlowDay {
  const CashFlowDay({
    required this.date,
    required this.moneyIn,
    required this.moneyOut,
  });

  final DateTime date;
  final num moneyIn;
  final num moneyOut;
}

/// What kind of event a dashboard activity entry represents.
enum ActivityKind { sale, loadOut, production }

extension ActivityKindIcon on ActivityKind {
  IconData get icon => switch (this) {
    ActivityKind.sale => Icons.point_of_sale_outlined,
    ActivityKind.loadOut => Icons.local_shipping_outlined,
    ActivityKind.production => Icons.factory_outlined,
  };
}

/// A single line in "today's activity" — the visible face of the audit
/// trail on the dashboard.
class ActivityEntry {
  const ActivityEntry({
    required this.time,
    required this.description,
    required this.actor,
    required this.kind,
  });

  final DateTime time;
  final String description;
  final String actor;
  final ActivityKind kind;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    time: DateTime.parse(json['time'] as String),
    description: json['description'] as String,
    actor: json['actor'] as String,
    kind: ActivityKind.values.byName(json['kind'] as String),
  );

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'description': description,
    'actor': actor,
    'kind': kind.name,
  };
}

/// A raw-material stock level that has dropped below its reorder point.
class LowStockAlert {
  const LowStockAlert({
    required this.materialName,
    required this.quantityRemaining,
    required this.unit,
  });

  final String materialName;
  final int quantityRemaining;
  final String unit;

  factory LowStockAlert.fromJson(Map<String, dynamic> json) => LowStockAlert(
    materialName: json['material_name'] as String,
    quantityRemaining: json['quantity_remaining'] as int,
    unit: json['unit'] as String,
  );

  Map<String, dynamic> toJson() => {
    'material_name': materialName,
    'quantity_remaining': quantityRemaining,
    'unit': unit,
  };
}

/// The report-at-a-glance shown on the dashboard: today's and all-time
/// headline numbers, money outside, cash flow, any low-stock alert, the
/// last payment received, and recent activity.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.bagsProducedToday,
    required this.cashCollectedToday,
    required this.totalBagsProduced,
    required this.totalRevenue,
    required this.totalCustomers,
    required this.moneyOutside,
    required this.overdueCustomerCount,
    required this.cashFlow,
    required this.recentActivity,
    this.lowStock,
    this.lastPayment,
  });

  final int bagsProducedToday;
  final num cashCollectedToday;
  final int totalBagsProduced;
  final num totalRevenue;
  final int totalCustomers;
  final num moneyOutside;
  final int overdueCustomerCount;
  final List<CashFlowDay> cashFlow;
  final LowStockAlert? lowStock;
  final RecentPayment? lastPayment;
  final List<ActivityEntry> recentActivity;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) =>
      DashboardSnapshot(
        bagsProducedToday: json['bags_produced_today'] as int,
        cashCollectedToday: json['cash_collected_today'] as num,
        totalBagsProduced: json['total_bags_produced'] as int,
        totalRevenue: json['total_revenue'] as num,
        totalCustomers: json['total_customers'] as int,
        moneyOutside: json['money_outside'] as num,
        overdueCustomerCount: json['overdue_customer_count'] as int,
        cashFlow: const [],
        lowStock: json['low_stock'] == null
            ? null
            : LowStockAlert.fromJson(json['low_stock'] as Map<String, dynamic>),
        recentActivity: (json['recent_activity'] as List<dynamic>)
            .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'bags_produced_today': bagsProducedToday,
    'cash_collected_today': cashCollectedToday,
    'total_bags_produced': totalBagsProduced,
    'total_revenue': totalRevenue,
    'total_customers': totalCustomers,
    'money_outside': moneyOutside,
    'overdue_customer_count': overdueCustomerCount,
    'low_stock': lowStock?.toJson(),
    'recent_activity': recentActivity.map((e) => e.toJson()).toList(),
  };
}
