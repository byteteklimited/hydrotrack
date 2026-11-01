import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/query_range.dart';
import '../../../../core/utils/rpc_params.dart';
import '../../../offline/data/models/offline_snapshot.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/cash_count.dart';

/// End-of-shift cash counts (migration 0020).
abstract class CashCountRepository {
  /// The signed-in person's expected cash right now.
  Future<ExpectedCash> fetchMyExpected();

  /// Records the signed-in person's count. [note] is required when it
  /// doesn't match (the server says so).
  Future<void> recordCount({required num counted, String? note});

  /// Counts in the range, newest first. Cashiers get only their own.
  Future<List<CashCount>> fetchCounts({DateTime? from, DateTime? to});

  /// Owner/Admin/Manager: confirms they checked the cash.
  Future<void> confirm(String countId);
}

class SupabaseCashCountRepository implements CashCountRepository {
  SupabaseCashCountRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const select =
      '*, cashier:profiles!cashier_id(full_name), '
      'confirmer:profiles!confirmed_by(full_name)';

  @override
  Future<ExpectedCash> fetchMyExpected() async {
    final row = await _client.rpc(
      'my_expected_cash',
      params: {'p_tenant_id': _tenantId},
    );
    return ExpectedCash.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<void> recordCount({required num counted, String? note}) {
    return _client.rpc(
      'record_cash_count',
      params: rpcParams(_tenantId, {'counted': counted, 'note': note}),
    );
  }

  @override
  Future<List<CashCount>> fetchCounts({DateTime? from, DateTime? to}) async {
    final rows = await _client
        .from('cash_counts')
        .select(select)
        .eq('tenant_id', _tenantId)
        .inRange('counted_at', from: from, to: to)
        .order('counted_at', ascending: false);
    return [
      for (final row in rows as List)
        CashCount.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> confirm(String countId) {
    return _client.rpc(
      'confirm_cash_count',
      params: rpcParams(_tenantId, {'count_id': countId}),
    );
  }
}

/// On a set-up device: counts are recorded on the device first; expected
/// cash is worked out from the device's data the same way the server does.
class OfflineCashCountRepository implements CashCountRepository {
  OfflineCashCountRepository(this._remote, this._offline);

  final CashCountRepository _remote;
  final OfflineContext _offline;

  @override
  Future<ExpectedCash> fetchMyExpected() {
    return _offline.read(
      remote: _remote.fetchMyExpected,
      local: (snapshot) =>
          localExpectedCash(snapshot, _offline.actor.id, DateTime.now()),
    );
  }

  @override
  Future<void> recordCount({required num counted, String? note}) async {
    await _offline.record(OperationType.cashCount, {
      'counted': counted,
      'note': note,
    });
  }

  @override
  Future<List<CashCount>> fetchCounts({DateTime? from, DateTime? to}) {
    return _offline.read(
      remote: () => _remote.fetchCounts(from: from, to: to),
      local: (snapshot) =>
          snapshot
              .rows('cash_counts')
              .map(CashCount.fromJson)
              .where((c) => isInRange(c.countedAt, from: from, to: to))
              .toList()
            ..sort((a, b) => b.countedAt.compareTo(a.countedAt)),
    );
  }

  @override
  Future<void> confirm(String countId) {
    return _offline.online(() => _remote.confirm(countId));
  }
}

/// Expected cash for [cashierId] at [until], from the device's data (same
/// rule as expected_cash_for on the server).
ExpectedCash localExpectedCash(
  OfflineSnapshot snapshot,
  String cashierId,
  DateTime until,
) {
  final dayStart = dateOnly(until);
  var since = dayStart;
  for (final count in snapshot.rows('cash_counts')) {
    final at = DateTime.parse(count['counted_at'] as String);
    if (count['cashier_id'] == cashierId &&
        at.isAfter(since) &&
        !at.isAfter(until)) {
      since = at;
    }
  }
  num cashIn = 0;
  num cashOut = 0;
  for (final entry in snapshot.rows('cash_entries')) {
    final created = entry['created_at'] as String?;
    if (entry['recorded_by'] != cashierId ||
        entry['method'] != 'cash' ||
        created == null) {
      continue;
    }
    final at = DateTime.parse(created);
    if (!at.isAfter(since) || at.isAfter(until)) continue;
    if (entry['direction'] == 'money_in') {
      cashIn += entry['amount'] as num;
    } else {
      cashOut += entry['amount'] as num;
    }
  }
  return ExpectedCash(since: since, cashIn: cashIn, cashOut: cashOut);
}
