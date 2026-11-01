import 'package:flutter/material.dart';

import '../../../../core/constants/payment_channel.dart';

export '../../../../core/constants/payment_channel.dart';

/// What kind of running cost an expense covers.
enum ExpenseCategory {
  electricity,
  fuelDiesel,
  maintenance,
  wages,
  materialsPurchase,
  transport,
  other,
}

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
    ExpenseCategory.electricity => 'Electricity',
    ExpenseCategory.fuelDiesel => 'Fuel / Diesel',
    ExpenseCategory.maintenance => 'Maintenance',
    ExpenseCategory.wages => 'Wages',
    ExpenseCategory.materialsPurchase => 'Materials purchase',
    ExpenseCategory.transport => 'Transport',
    ExpenseCategory.other => 'Other',
  };

  /// The exact string stored in Postgres (`expense_category` enum).
  String get dbValue => switch (this) {
    ExpenseCategory.electricity => 'electricity',
    ExpenseCategory.fuelDiesel => 'fuel_diesel',
    ExpenseCategory.maintenance => 'maintenance',
    ExpenseCategory.wages => 'wages',
    ExpenseCategory.materialsPurchase => 'materials_purchase',
    ExpenseCategory.transport => 'transport',
    ExpenseCategory.other => 'other',
  };

  /// A distinct glyph per category so a list/table reads at a glance —
  /// always shown in the same neutral icon-badge treatment every other
  /// list tile in this app uses (varying the glyph, never the color).
  /// This screen tracks running costs, not a threshold or a direction,
  /// so category is never itself a reason to reach for red/amber/green.
  IconData get icon => switch (this) {
    ExpenseCategory.electricity => Icons.bolt_outlined,
    ExpenseCategory.fuelDiesel => Icons.local_gas_station_outlined,
    ExpenseCategory.maintenance => Icons.build_outlined,
    ExpenseCategory.wages => Icons.payments_outlined,
    ExpenseCategory.materialsPurchase => Icons.inventory_2_outlined,
    ExpenseCategory.transport => Icons.local_shipping_outlined,
    ExpenseCategory.other => Icons.receipt_long_outlined,
  };
}

/// `expenses.category` is a Postgres enum with snake_case values.
ExpenseCategory expenseCategoryFromDb(String value) => switch (value) {
  'electricity' => ExpenseCategory.electricity,
  'fuel_diesel' => ExpenseCategory.fuelDiesel,
  'maintenance' => ExpenseCategory.maintenance,
  'wages' => ExpenseCategory.wages,
  'materials_purchase' => ExpenseCategory.materialsPurchase,
  'transport' => ExpenseCategory.transport,
  'other' => ExpenseCategory.other,
  _ => throw ArgumentError('Unknown expense category: $value'),
};

/// One running cost — electricity, diesel, wages, or anything else that
/// keeps the factory operating.
class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.method,
    required this.recordedBy,
  });

  final String id;
  final DateTime date;
  final ExpenseCategory category;
  final String description;
  final num amount;
  final PaymentChannel method;
  final String recordedBy;

  /// `recorded_by` is a Postgres FK to `profiles`, so a row fetched from
  /// Supabase carries the joined `profiles.full_name` here instead of the
  /// raw id.
  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    category: expenseCategoryFromDb(json['category'] as String),
    description: json['description'] as String,
    amount: json['amount'] as num,
    method: PaymentChannel.values.byName(json['method'] as String),
    recordedBy:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        'Unknown',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'category': category.dbValue,
    'description': description,
    'amount': amount,
    'method': method.name,
    'recorded_by': recordedBy,
  };
}
