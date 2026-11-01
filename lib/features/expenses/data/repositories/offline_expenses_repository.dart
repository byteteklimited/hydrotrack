import '../../../../core/utils/date_utils.dart';
import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/expense.dart';
import 'expenses_repository.dart';

/// Expenses on a device set up for offline use: recorded on the device
/// first, then sent.
class OfflineExpensesRepository implements ExpensesRepository {
  OfflineExpensesRepository(this._remote, this._offline);

  final ExpensesRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Expense>> fetchExpenses({DateTime? from, DateTime? to}) {
    return _offline.read(
      remote: () => _remote.fetchExpenses(from: from, to: to),
      local: (snapshot) =>
          snapshot
              .rows('expenses')
              .map(Expense.fromJson)
              .where((e) => isInRange(e.date, from: from, to: to))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  @override
  Future<void> recordExpense(Expense expense) async {
    await _offline.record(
      OperationType.expense,
      SupabaseExpensesRepository.recordExpensePayload(expense),
    );
  }
}
