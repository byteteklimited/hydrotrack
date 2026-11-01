import 'package:flutter/material.dart';

import '../../../auth/data/models/staff_user.dart';

/// Which part of the app an audit entry came from — drives its icon in
/// the audit trail list.
enum AuditCategory {
  production,
  inventory,
  sales,
  debts,
  finance,
  distribution,
  expenses,
  staff,
}

extension AuditCategoryIcon on AuditCategory {
  /// Always the neutral muted-gray treatment every icon in the audit
  /// trail already used — a category glyph for quick scanning, never a
  /// second color system.
  IconData get icon => switch (this) {
    AuditCategory.production => Icons.factory_outlined,
    AuditCategory.inventory => Icons.inventory_2_outlined,
    AuditCategory.sales => Icons.point_of_sale_outlined,
    AuditCategory.debts => Icons.receipt_long_outlined,
    AuditCategory.finance => Icons.account_balance_outlined,
    AuditCategory.distribution => Icons.local_shipping_outlined,
    AuditCategory.expenses => Icons.payments_outlined,
    AuditCategory.staff => Icons.badge_outlined,
  };
}

/// "Who did what, and when" — one row per recorded action, across every
/// feature, for the audit trail.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.staffName,
    required this.role,
    required this.category,
    required this.description,
    required this.timestamp,
  });

  final String id;
  final String staffName;
  final StaffRole role;
  final AuditCategory category;
  final String description;
  final DateTime timestamp;

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String,
      staffName: json['staff_name'] as String,
      role: staffRoleFromDb(json['role'] as String),
      category: AuditCategory.values.byName(json['category'] as String),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'staff_name': staffName,
    'role': staffRoleToDb(role),
    'category': category.name,
    'description': description,
    'at': timestamp.toIso8601String(),
  };
}
