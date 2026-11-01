import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/query_range.dart';
import '../models/cash_entry.dart';
import '../models/finance_position.dart';

/// Contract for reading and recording cash movements. Sales and Debts
/// write here automatically (see supabase/migrations/0006_business_rpcs.sql); Expenses will too once
/// it's wired.
abstract class FinanceRepository {
  /// Most recent first. [from] inclusive, [to] exclusive.
  Future<List<CashEntry>> fetchEntries({DateTime? from, DateTime? to});

  /// Running cash-in-hand and bank balance — the sum of every real entry
  /// by method. There's no fabricated opening balance; if the business
  /// has real cash on hand before using this system, record it as a
  /// manual entry (source: Other) to establish that starting position.
  Future<FinancePosition> fetchPosition();

  Future<void> recordEntry(CashEntry entry);
}

/// Backed by `cash_entries`.
class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectWithRecorder = '*, profiles!recorded_by(full_name)';

  @override
  Future<List<CashEntry>> fetchEntries({DateTime? from, DateTime? to}) async {
    final rows = await _client
        .from('cash_entries')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .inRange('date_time', from: from, to: to)
        .order('date_time', ascending: false);
    return (rows as List)
        .map((row) => CashEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FinancePosition> fetchPosition() async {
    final rows = await _client
        .from('cash_entries')
        .select('direction, amount, method')
        .eq('tenant_id', _tenantId);
    num cash = 0;
    num bank = 0;
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final signed = map['direction'] == 'money_in'
          ? map['amount'] as num
          : -(map['amount'] as num);
      if (map['method'] == 'cash') {
        cash += signed;
      } else {
        bank += signed;
      }
    }
    return FinancePosition(cashInHand: cash, bankBalance: bank);
  }

  @override
  Future<void> recordEntry(CashEntry entry) async {
    final currentUserId = _client.auth.currentUser!.id;
    await _client.from('cash_entries').insert({
      'tenant_id': _tenantId,
      'date_time': entry.dateTime.toIso8601String(),
      'direction': entry.direction.dbValue,
      'source': entry.source.dbValue,
      'amount': entry.amount,
      'method': entry.method.name,
      'note': entry.note,
      'recorded_by': currentUserId,
    });
  }
}
