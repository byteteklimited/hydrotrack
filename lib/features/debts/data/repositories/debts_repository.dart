import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../models/recent_payment.dart';

/// Contract for reading customer balances and their ledgers, and for
/// recording payments/credit-limit changes.
abstract class DebtsRepository {
  Future<List<Customer>> fetchCustomers();
  Future<List<LedgerEntry>> fetchLedger(String customerId);

  /// The most recent payment received, across every customer — for the
  /// dashboard's "last payment" card. Null if none has ever been recorded.
  Future<RecentPayment?> fetchMostRecentPayment();
  Future<Customer> recordPayment({
    required String customerId,
    required num amount,
    required PaymentChannel channel,
    required DateTime date,
    String? note,
  });
  Future<Customer> updateCreditLimit({
    required String customerId,
    required num newLimit,
  });

  /// Adds a new distributor/credit customer. Starts at zero balance with
  /// no payment history — a real customer, not a seeded one.
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String area,
    required num creditLimit,
  });

  /// Sets a debt/credit position that predates this system — [amount]
  /// is signed (positive: the customer already owed money; negative:
  /// they already had credit). Admin only, enforced server-side.
  Future<Customer> addOpeningBalance({
    required String customerId,
    required num amount,
    required String reason,
  });

  /// Forgives [amount] of debt with no payment received — [amount] is
  /// always positive. Admin only, enforced server-side.
  Future<Customer> writeOffDebt({
    required String customerId,
    required num amount,
    required String reason,
  });
}

/// Backed by `customers`/`ledger_entries`. Writes go through the
/// `record_customer_payment` and `update_customer_credit_limit` Postgres
/// functions (supabase/migrations/0006_business_rpcs.sql) — each has its own role check (payments:
/// Admin/Manager/Cashier; credit limit: Admin/Manager only), which a
/// single table-level RLS policy can't express since both would touch
/// the same row.
class SupabaseDebtsRepository implements DebtsRepository {
  SupabaseDebtsRepository(this._tenantId);

  /// Every query and write is scoped to this organization.
  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<Customer>> fetchCustomers() async {
    final rows = await _client
        .from('customers')
        .select()
        .eq('tenant_id', _tenantId)
        .order('name');
    return (rows as List)
        .map((row) => Customer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String customerId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('tenant_id', _tenantId)
        .eq('customer_id', customerId)
        .order('date');
    return (rows as List)
        .map((row) => LedgerEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RecentPayment?> fetchMostRecentPayment() async {
    final rows = await _client
        .from('ledger_entries')
        .select('amount, date, customers(name)')
        .eq('tenant_id', _tenantId)
        .eq('type', 'payment')
        .order('date', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    final customerName =
        (row['customers'] as Map<String, dynamic>?)?['name'] as String? ??
        'Unknown';
    return RecentPayment(
      customerName: customerName,
      amount: row['amount'] as num,
      date: DateTime.parse(row['date'] as String),
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
    final entryNote = (note == null || note.trim().isEmpty)
        ? '${channel.label} payment'
        : '${channel.label} — ${note.trim()}';

    final row = await _client.rpc(
      'record_customer_payment',
      params: {
        'p_tenant_id': _tenantId,
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_channel': channel.name,
        'p_date': date.toIso8601String().split('T').first,
        'p_note': entryNote,
      },
    );
    return Customer.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<Customer> updateCreditLimit({
    required String customerId,
    required num newLimit,
  }) async {
    final row = await _client.rpc(
      'update_customer_credit_limit',
      params: {
        'p_tenant_id': _tenantId,
        'p_customer_id': customerId,
        'p_new_limit': newLimit,
      },
    );
    return Customer.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String area,
    required num creditLimit,
  }) async {
    final row = await _client
        .from('customers')
        .insert({
          'tenant_id': _tenantId,
          'name': name,
          'phone': phone,
          'area': area,
          'credit_limit': creditLimit,
          'balance': 0,
        })
        .select()
        .single();
    return Customer.fromJson(row);
  }

  @override
  Future<Customer> addOpeningBalance({
    required String customerId,
    required num amount,
    required String reason,
  }) async {
    final row = await _client.rpc(
      'add_opening_balance',
      params: {
        'p_tenant_id': _tenantId,
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_reason': reason,
      },
    );
    return Customer.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<Customer> writeOffDebt({
    required String customerId,
    required num amount,
    required String reason,
  }) async {
    final row = await _client.rpc(
      'write_off_debt',
      params: {
        'p_tenant_id': _tenantId,
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_reason': reason,
      },
    );
    return Customer.fromJson(row as Map<String, dynamic>);
  }
}
