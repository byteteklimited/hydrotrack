import 'dart:convert';

import 'offline_member.dart';

/// The organization's data kept on this device: what `device-sync`
/// downloaded, with records made here since then already applied on top.
/// Table rows have exactly the shape the app's own Supabase queries
/// return, so the usual model `fromJson` constructors read them.
///
/// Mutable on purpose: records made offline update it in place
/// (see LocalBookkeeping); callers persist it afterwards.
class OfflineSnapshot {
  OfflineSnapshot({
    required this.pulledAt,
    required this.historySince,
    required this.organization,
    required this.members,
    required this.tables,
    required this.cashInHand,
    required this.bankBalance,
    this.totalBagsProduced = 0,
    this.totalRevenue = 0,
    this.lastStockCountAt,
    this.subscription,
    this.location,
  });

  final DateTime pulledAt;

  /// Sales, payments etc. older than this aren't on the device.
  final DateTime historySince;
  final Map<String, dynamic> organization;
  final List<OfflineMember> members;
  final Map<String, List<Map<String, dynamic>>> tables;
  num cashInHand;
  num bankBalance;

  /// All-time, from the server, plus records made here since.
  int totalBagsProduced;
  num totalRevenue;
  DateTime? lastStockCountAt;

  /// The organization's subscription as of the last download (`my_subscription`
  /// shape), or null from an older download.
  final Map<String, dynamic>? subscription;

  /// The location this device belongs to (`{id, name, kind}`); null from
  /// a download made before locations existed.
  final Map<String, dynamic>? location;

  List<Map<String, dynamic>> rows(String table) =>
      tables.putIfAbsent(table, () => []);

  Map<String, dynamic>? row(String table, String id) {
    for (final row in rows(table)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  OfflineMember? member(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  /// A deep, independent copy.
  OfflineSnapshot copy() => OfflineSnapshot.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );

  /// From a `device-sync` pull response.
  factory OfflineSnapshot.fromPull(Map<String, dynamic> json) {
    final position = json['finance_position'] as Map<String, dynamic>;
    return OfflineSnapshot(
      pulledAt: DateTime.parse(json['pulled_at'] as String),
      historySince: DateTime.parse(json['history_since'] as String),
      organization: Map<String, dynamic>.from(json['organization'] as Map),
      members: [
        for (final member in json['members'] as List)
          OfflineMember.fromJson(Map<String, dynamic>.from(member as Map)),
      ],
      tables: {
        for (final entry in (json['tables'] as Map).entries)
          entry.key as String: [
            for (final row in entry.value as List)
              Map<String, dynamic>.from(row as Map),
          ],
      },
      cashInHand: position['cash_in_hand'] as num,
      bankBalance: position['bank_balance'] as num,
      totalBagsProduced:
          ((json['totals'] as Map?)?['total_bags_produced'] as num?)?.toInt() ??
          0,
      totalRevenue: (json['totals'] as Map?)?['total_revenue'] as num? ?? 0,
      lastStockCountAt: json['last_stock_count_at'] == null
          ? null
          : DateTime.parse(json['last_stock_count_at'] as String),
      subscription: json['subscription'] == null
          ? null
          : Map<String, dynamic>.from(json['subscription'] as Map),
      location: json['location'] == null
          ? null
          : Map<String, dynamic>.from(json['location'] as Map),
    );
  }

  factory OfflineSnapshot.fromJson(Map<String, dynamic> json) =>
      OfflineSnapshot.fromPull(json);

  Map<String, dynamic> toJson() => {
    'pulled_at': pulledAt.toUtc().toIso8601String(),
    'history_since': historySince.toUtc().toIso8601String(),
    'organization': organization,
    'members': [for (final member in members) member.toJson()],
    'tables': tables,
    'finance_position': {
      'cash_in_hand': cashInHand,
      'bank_balance': bankBalance,
    },
    'totals': {
      'total_bags_produced': totalBagsProduced,
      'total_revenue': totalRevenue,
    },
    'last_stock_count_at': lastStockCountAt?.toUtc().toIso8601String(),
    'subscription': subscription,
    'location': location,
  };
}
