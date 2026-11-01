import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';

/// Contract for reading and recording expenses.
abstract class ExpensesRepository {
  Future<List<Expense>> fetchExpenses();
  Future<void> recordExpense(Expense expense);
}

/// Backed by `expenses`. `recordExpense` calls the `record_expense`
/// Postgres function (supabase/migrations/0006_business_rpcs.sql), which also posts a matching
/// `cash_entries` row — the last of the "appears here automatically"
/// links promised back in Step 10.
class SupabaseExpensesRepository implements ExpensesRepository {
  SupabaseExpensesRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  static const _selectWithRecorder = '*, profiles!recorded_by(full_name)';

  @override
  Future<List<Expense>> fetchExpenses() async {
    final rows = await _client
        .from('expenses')
        .select(_selectWithRecorder)
        .eq('tenant_id', _tenantId)
        .order('date', ascending: false);
    return (rows as List)
        .map((row) => Expense.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> recordExpense(Expense expense) {
    return _client.rpc(
      'record_expense',
      params: {
        'p_tenant_id': _tenantId,
        'p_date': expense.date.toIso8601String().split('T').first,
        'p_category': expense.category.dbValue,
        'p_description': expense.description,
        'p_amount': expense.amount,
        'p_method': expense.method.name,
      },
    );
  }
}
