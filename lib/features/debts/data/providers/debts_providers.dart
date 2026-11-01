import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../repositories/debts_repository.dart';
import '../repositories/offline_debts_repository.dart';

/// The active [DebtsRepository] implementation.
final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  final remote = SupabaseDebtsRepository(ref.watch(dataScopeProvider).tenantId);
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineDebtsRepository(remote, offline);
});

/// All customers.
final customersProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(debtsRepositoryProvider).fetchCustomers();
});

/// One customer's ledger, oldest first (so a running balance can be
/// folded forward before display).
final customerLedgerProvider = FutureProvider.family<List<LedgerEntry>, String>(
  (ref, customerId) {
    return ref.watch(debtsRepositoryProvider).fetchLedger(customerId);
  },
);

/// The headline figures: total money outside (and how many customers
/// make it up), plus the separate "other direction" figure — money the
/// business owes back to customers who've overpaid.
class DebtsSummary {
  const DebtsSummary({
    required this.totalOutside,
    required this.customersOwing,
    required this.overdueCount,
    required this.totalCredit,
    required this.customersInCredit,
  });

  final num totalOutside;
  final int customersOwing;
  final int overdueCount;

  /// Always a positive magnitude — "how much credit is outstanding",
  /// not a signed balance sum.
  final num totalCredit;
  final int customersInCredit;
}

final debtsSummaryProvider = Provider<AsyncValue<DebtsSummary>>((ref) {
  return ref.watch(customersProvider).whenData((customers) {
    final owing = customers.where((c) => c.balance > 0);
    final inCredit = customers.where((c) => c.isInCredit);
    return DebtsSummary(
      totalOutside: owing.fold<num>(0, (sum, c) => sum + c.balance),
      customersOwing: owing.length,
      overdueCount: owing.where((c) => c.isOverdue).length,
      totalCredit: inCredit.fold<num>(0, (sum, c) => sum + -c.balance),
      customersInCredit: inCredit.length,
    );
  });
});

/// Drives "Record payment", "Edit credit limit", and "Add customer":
/// loading while the write is in flight, error (most commonly no
/// connection) if it fails — otherwise refreshes the affected customer
/// and their ledger.
class DebtActionController extends ActionController {
  DebtActionController(this._ref);

  final Ref _ref;

  Future<Customer?> recordPayment({
    required String customerId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  }) {
    return guard(() async {
      final updated = await _ref
          .read(debtsRepositoryProvider)
          .recordPayment(
            customerId: customerId,
            amount: amount,
            channel: channel,
            date: date,
            note: note,
          );
      _refresh(customerId);
      return updated;
    });
  }

  Future<void> updateCreditLimit({
    required String customerId,
    required num newLimit,
  }) {
    return guard(() async {
      await _ref
          .read(debtsRepositoryProvider)
          .updateCreditLimit(customerId: customerId, newLimit: newLimit);
      _refresh(customerId);
    });
  }

  Future<Customer?> createCustomer({
    required String name,
    required String phone,
    required String area,
    required num creditLimit,
  }) {
    return guard(() async {
      final created = await _ref
          .read(debtsRepositoryProvider)
          .createCustomer(
            name: name,
            phone: phone,
            area: area,
            creditLimit: creditLimit,
          );
      _ref.invalidate(customersProvider);
      return created;
    });
  }

  Future<Customer?> addOpeningBalance({
    required String customerId,
    required num amount,
    required String reason,
  }) {
    return guard(() async {
      final updated = await _ref
          .read(debtsRepositoryProvider)
          .addOpeningBalance(
            customerId: customerId,
            amount: amount,
            reason: reason,
          );
      _refresh(customerId);
      return updated;
    });
  }

  Future<Customer?> writeOffDebt({
    required String customerId,
    required num amount,
    required String reason,
  }) {
    return guard(() async {
      final updated = await _ref
          .read(debtsRepositoryProvider)
          .writeOffDebt(customerId: customerId, amount: amount, reason: reason);
      _refresh(customerId);
      return updated;
    });
  }

  void _refresh(String customerId) {
    _ref.invalidate(customersProvider);
    _ref.invalidate(customerLedgerProvider(customerId));
  }
}

final debtActionControllerProvider =
    StateNotifierProvider<DebtActionController, AsyncValue<void>>(
      (ref) => DebtActionController(ref),
    );
