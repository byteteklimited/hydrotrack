import '../../../offline/data/services/offline_context.dart';
import '../models/cash_entry.dart';
import '../models/finance_position.dart';
import 'finance_repository.dart';

/// The cash book on a device set up for offline use. Cash from sales,
/// payments and expenses made offline is already included; manual cash
/// entries need internet.
class OfflineFinanceRepository implements FinanceRepository {
  OfflineFinanceRepository(this._remote, this._offline);

  final FinanceRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<CashEntry>> fetchEntries() {
    return _offline.read(
      remote: _remote.fetchEntries,
      local: (snapshot) =>
          snapshot.rows('cash_entries').map(CashEntry.fromJson).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
    );
  }

  @override
  Future<FinancePosition> fetchPosition() {
    return _offline.read(
      remote: _remote.fetchPosition,
      local: (snapshot) => FinancePosition(
        cashInHand: snapshot.cashInHand,
        bankBalance: snapshot.bankBalance,
      ),
    );
  }

  @override
  Future<void> recordEntry(CashEntry entry) {
    return _offline.online(() => _remote.recordEntry(entry));
  }
}
