import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/rpc_params.dart';
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

  /// record_expense's values (without the `p_` prefix), shared with
  /// offline mode.
  static Map<String, dynamic> recordExpensePayload(Expense expense) => {
    'date': dateParam(expense.date),
    'category': expense.category.dbValue,
    'description': expense.description,
    'amount': expense.amount,
    'method': expense.method.name,
  };

  @override
  Future<void> recordExpense(Expense expense) {
    return _client.rpc(
      'record_expense',
      params: rpcParams(_tenantId, recordExpensePayload(expense)),
    );
  }
}
