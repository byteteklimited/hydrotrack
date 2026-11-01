import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/customer.dart';
import 'package:hydrotrack/features/distribution/data/models/load_out.dart';
import 'package:hydrotrack/features/finance/data/models/cash_entry.dart';
import 'package:hydrotrack/features/offline/data/models/offline_snapshot.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/services/local_bookkeeping.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';

import 'offline_fixtures.dart';

OutboxOperation _op(
  OperationType type,
  Map<String, dynamic> payload, {
  String id = 'op-1',
}) {
  return OutboxOperation(
    opId: id,
    seq: 1,
    type: type,
    actorId: cashierId,
    actorName: 'Carol Cashier',
    recordedAt: DateTime.utc(2026, 11, 1, 9, 30),
    payload: payload,
  );
}

int _stock(OfflineSnapshot s, String id) =>
    s.row('stock_items', id)!['quantity_on_hand'] as int;

void main() {
  test('a cash sale takes stock oldest batch first and adds the cash', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(s, _op(OperationType.sale, salePayload(bags: 70)));

    final sale = Sale.fromJson(s.row('sales', 'op-1')!);
    expect(sale.total, 28000);
    expect(sale.lines.single.quantity, 70);
    expect(_stock(s, sachetId), 30);
    expect(s.row('stock_batches', 'batch-old')!['quantity_remaining'], 0);
    expect(s.row('stock_batches', 'batch-new')!['quantity_remaining'], 30);
    expect(s.cashInHand, 78000);
    expect(CashEntry.fromJson(s.rows('cash_entries').single).amount, 28000);
  });

  test('a credit sale adds to the distributor balance and ledger', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.sale, salePayload(bags: 10, credit: 4000)),
    );
    expect(Customer.fromJson(s.row('customers', musaId)!).balance, 9000);
    expect(s.rows('ledger_entries').single['type'], 'sale');
    expect(s.rows('cash_entries'), isEmpty);
  });

  test('stock can go below zero offline (the server flags it)', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(s, _op(OperationType.sale, salePayload(bags: 150)));
    expect(_stock(s, sachetId), -50);
  });

  test('a payment lowers the balance and records cash', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.customerPayment, {
        'customer_id': musaId,
        'amount': 2000,
        'channel': 'transfer',
        'date': '2026-11-01',
        'note': 'Transfer payment',
      }),
    );
    final customer = Customer.fromJson(s.row('customers', musaId)!);
    expect(customer.balance, 3000);
    expect(customer.lastPaymentDate, DateTime(2026, 11, 1));
    expect(s.bankBalance, 22000);
  });

  test('production uses raw material by recipe and adds the bags', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.productionRun, {
        'date': '2026-11-01',
        'shift': 'morning',
        'machine': 'Machine 1',
        'operator_name': 'Musa',
        'product_id': sachetProductId,
        'quantity_produced': 480,
        'wastage': 20,
        'expiry_date': null,
      }),
    );
    expect(
      ProductionRun.fromJson(
        s.row('production_runs', 'op-1')!,
      ).quantityProduced,
      480,
    );
    expect(_stock(s, nylonId), 5, reason: '500 bags at 1 roll per 100');
    expect(_stock(s, sachetId), 580);
  });

  test('an expense records money out', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.expense, {
        'date': '2026-11-01',
        'category': 'fuel_diesel',
        'description': 'Diesel',
        'amount': 15000,
        'method': 'cash',
      }),
    );
    expect(s.rows('expenses').single['description'], 'Diesel');
    expect(s.cashInHand, 35000);
  });

  test('a stock count sets the count and remembers when', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.stockCount, {
        'item_id': sachetId,
        'new_count': 95,
        'note': 'Count',
      }),
    );
    expect(_stock(s, sachetId), 95);
    expect(s.lastStockCountAt, DateTime.utc(2026, 11, 1, 9, 30));
  });

  test('a load-out and its driver return, both offline (a record queued '
      'before products were per organization still matches)', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.loadOut, {
        'driver_id': 'driver-1',
        'vehicle_id': 'vehicle-1',
        'product': 'sachet50cl',
        'bags_loaded': 40,
        'note': null,
      }, id: 'load-op'),
    );
    expect(_stock(s, sachetId), 60);

    LocalBookkeeping.apply(
      s,
      _op(OperationType.driverReturn, {
        'load_out_op_id': 'load-op',
        'bags_sold': 30,
        'bags_returned': 10,
        'bags_damaged': 0,
        'cash_returned': 12000,
        'unit_price': 400,
        'amount_paid': 12000,
        'payment_method': 'cash',
        'customer_type': 'walk_in',
      }, id: 'return-op'),
    );
    final trip = LoadOut.fromJson(s.row('load_outs', 'load-op')!);
    expect(trip.status, LoadOutStatus.settled);
    expect(_stock(s, sachetId), 70);
    expect(Sale.fromJson(s.row('sales', 'return-op-sale')!).total, 12000);
  });

  test('a new customer can be sold to on credit straight away', () {
    final s = sampleSnapshot();
    LocalBookkeeping.apply(
      s,
      _op(OperationType.customer, {
        'id': 'new-customer',
        'name': 'New Shop',
        'phone': '08022223333',
        'area': 'Zaria',
        'credit_limit': 20000,
      }),
    );
    expect(Customer.fromJson(s.row('customers', 'new-customer')!).balance, 0);
  });
}
