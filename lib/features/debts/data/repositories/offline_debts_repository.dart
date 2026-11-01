import '../../../offline/data/models/outbox_operation.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../models/recent_payment.dart';
import 'debts_repository.dart';

/// Customers and debts on a device set up for offline use. Payments and
/// new customers are recorded on the device first; credit limits,
/// opening balances and write-offs need internet.
class OfflineDebtsRepository implements DebtsRepository {
  OfflineDebtsRepository(this._remote, this._offline);

  final DebtsRepository _remote;
  final OfflineContext _offline;

  Customer _customer(String id) =>
      Customer.fromJson(_offline.snapshot.row('customers', id)!);

  @override
  Future<List<Customer>> fetchCustomers() {
    return _offline.read(
      remote: _remote.fetchCustomers,
      local: (snapshot) =>
          snapshot.rows('customers').map(Customer.fromJson).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String customerId) {
    return _offline.read(
      remote: () => _remote.fetchLedger(customerId),
      local: (snapshot) =>
          snapshot
              .rows('ledger_entries')
              .where((row) => row['customer_id'] == customerId)
              .map(LedgerEntry.fromJson)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  @override
  Future<RecentPayment?> fetchMostRecentPayment() {
    return _offline.read(
      remote: _remote.fetchMostRecentPayment,
      local: (snapshot) {
        final payments =
            snapshot
                .rows('ledger_entries')
                .where((row) => row['type'] == 'payment')
                .toList()
              ..sort(
                (a, b) => (b['date'] as String).compareTo(a['date'] as String),
              );
        if (payments.isEmpty) return null;
        final row = payments.first;
        return RecentPayment(
          customerName:
              (row['customers'] as Map?)?['name'] as String? ?? 'Unknown',
          amount: row['amount'] as num,
          date: DateTime.parse(row['date'] as String),
        );
      },
    );
  }

  @override
  Future<Customer> recordPayment({
    required String customerId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) async {
    await _offline.record(
      OperationType.customerPayment,
      SupabaseDebtsRepository.recordPaymentPayload(
        customerId: customerId,
        amount: amount,
        channel: channel,
        date: date,
        note: note,
      ),
    );
    return _customer(customerId);
  }

  @override
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String area,
    required num creditLimit,
  }) async {
    final id = _offline.newId();
    await _offline.record(OperationType.customer, {
      'id': id,
      'name': name,
      'phone': phone,
      'area': area,
      'credit_limit': creditLimit,
    });
    return _customer(id);
  }

  @override
  Future<Customer> updateCreditLimit({
    required String customerId,
    required num newLimit,
  }) {
    return _offline.online(
      () => _remote.updateCreditLimit(
        customerId: _syncedId(customerId),
        newLimit: newLimit,
      ),
    );
  }

  @override
  Future<Customer> addOpeningBalance({
    required String customerId,
    required num amount,
    required String reason,
  }) {
    return _offline.online(
      () => _remote.addOpeningBalance(
        customerId: _syncedId(customerId),
        amount: amount,
        reason: reason,
      ),
    );
  }

  @override
  Future<Customer> writeOffDebt({
    required String customerId,
    required num amount,
    required String reason,
  }) {
    return _offline.online(
      () => _remote.writeOffDebt(
        customerId: _syncedId(customerId),
        amount: amount,
        reason: reason,
      ),
    );
  }

  /// Customers made on this device keep their id on the server, but only
  /// exist there once synced.
  String _syncedId(String customerId) {
    return _offline.serverIdOr(
      customerId,
      notSyncedMessage:
          "This customer hasn't reached the server yet. Try again once it "
          'has synced.',
    );
  }
}
