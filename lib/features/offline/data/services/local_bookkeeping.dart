import '../models/offline_snapshot.dart';
import '../models/outbox_operation.dart';

/// Applies a record made on this device to the device's copy of the
/// data, the way the server will when it receives it (record_sale,
/// record_customer_payment, … in migration 0006), so lists, stock levels,
/// balances and cash totals are right before it syncs. Rows it creates
/// carry `local_op_id`, the record's id until the server gives it one.
///
/// After every download the server's data replaces this copy and the
/// records still waiting are applied again on top, so small differences
/// here never last.
class LocalBookkeeping {
  LocalBookkeeping._(this._snapshot, this._op);

  final OfflineSnapshot _snapshot;
  final OutboxOperation _op;

  static void apply(OfflineSnapshot snapshot, OutboxOperation op) {
    LocalBookkeeping._(snapshot, op)._apply();
  }

  Map<String, dynamic> get _p => _op.payload;
  String get _tenantId => _snapshot.organization['id'] as String;
  String get _at => _op.recordedAt.toUtc().toIso8601String();
  String get _today => _op.recordedAt.toIso8601String().split('T').first;
  Map<String, dynamic> get _recorder => {'full_name': _op.actorName};

  int _childCount = 0;
  String _childId() => '${_op.opId}-${_childCount++}';

  void _apply() {
    switch (_op.type) {
      case OperationType.sale:
        _sale(
          id: _op.opId,
          customerType: _p['customer_type'] as String,
          customerName: _p['customer_name'] as String?,
          total: _p['total'] as num,
          amountPaid: _p['amount_paid'] as num,
          paymentMethod: _p['payment_method'] as String,
          balance: _p['balance'] as num,
          lines: [
            for (final line in _p['lines'] as List)
              Map<String, dynamic>.from(line as Map),
          ],
          paidChannel: _p['paid_channel'] as String?,
        );
      case OperationType.customerPayment:
        _customerPayment();
      case OperationType.expense:
        _expense();
      case OperationType.productionRun:
        _productionRun();
      case OperationType.customer:
        _customer();
      case OperationType.stockIn:
        _stockIn();
      case OperationType.stockCount:
        _stockCount();
      case OperationType.loadOut:
        _loadOut();
      case OperationType.driverReturn:
        _driverReturn();
    }
  }

  // ---------------------------------------------------------------------
  // Records
  // ---------------------------------------------------------------------

  void _sale({
    required String id,
    required String customerType,
    required String? customerName,
    required num total,
    required num amountPaid,
    required String paymentMethod,
    required num balance,
    required List<Map<String, dynamic>> lines,
    required String? paidChannel,
    String noteSuffix = '',
  }) {
    _snapshot.rows('sales').add({
      'id': id,
      'tenant_id': _tenantId,
      'date_time': _at,
      'customer_type': customerType,
      'customer_name': customerName,
      'total': total,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'balance': balance,
      'recorded_by': _op.actorId,
      'voided_at': null,
      'voided_by': null,
      'void_reason': null,
      'sale_lines': [
        for (final line in lines)
          {
            'id': _childId(),
            'tenant_id': _tenantId,
            'sale_id': id,
            ..._productFields(_productId(line)),
            'quantity': line['quantity'],
            'unit_price': line['unit_price'],
            'list_price': line['list_price'],
          },
      ],
      'profiles': _recorder,
      'voided_by_profile': null,
      'local_op_id': _op.opId,
    });

    for (final line in lines) {
      final item = _finishedItem(_productId(line));
      if (item != null) {
        _takeStock(
          item,
          line['quantity'] as int,
          'stock_out',
          'Sold',
          saleId: id,
        );
      }
    }

    if (customerType == 'distributor' && balance > 0 && customerName != null) {
      final customer = _customerNamed(customerName);
      if (customer != null) {
        _ledger(
          customer,
          'sale',
          balance,
          'Sale — balance carried to account$noteSuffix',
          saleId: id,
        );
        customer['balance'] = (customer['balance'] as num) + balance;
      }
    }

    if (amountPaid > 0) {
      final channel = paymentMethod == 'cash' || paymentMethod == 'transfer'
          ? paymentMethod
          : paidChannel;
      if (channel != null) {
        final who = customerType == 'distributor'
            ? 'Sale — $customerName'
            : 'Sale — walk-in';
        _cash(
          'money_in',
          'sales',
          amountPaid,
          channel,
          '$who$noteSuffix',
          saleId: id,
        );
      }
    }
  }

  void _customerPayment() {
    final customer = _snapshot.row('customers', _p['customer_id'] as String);
    if (customer == null) return;
    final amount = _p['amount'] as num;
    final date = _p['date'] as String;
    customer['balance'] = (customer['balance'] as num) - amount;
    customer['last_payment_date'] = date;
    _ledger(customer, 'payment', amount, _p['note'] as String?, date: date);
    _cash(
      'money_in',
      'debt_payment',
      amount,
      _p['channel'] as String,
      _p['note'] as String?,
      dateTime: '${date}T00:00:00Z',
    );
  }

  void _expense() {
    final date = _p['date'] as String;
    final category = _p['category'] as String;
    _snapshot.rows('expenses').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'date': date,
      'category': category,
      'description': _p['description'],
      'amount': _p['amount'],
      'method': _p['method'],
      'recorded_by': _op.actorId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    _cash(
      'money_out',
      category == 'wages' ? 'wages' : 'expense',
      _p['amount'] as num,
      _p['method'] as String,
      _p['description'] as String?,
      dateTime: '${date}T00:00:00Z',
    );
  }

  void _productionRun() {
    final product = _productId(_p);
    final produced = _p['quantity_produced'] as int;
    final bags = produced + (_p['wastage'] as int);
    _snapshot.rows('production_runs').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'date': _p['date'],
      'shift': _p['shift'],
      'machine': _p['machine'],
      'operator_name': _p['operator_name'],
      ..._productFields(product),
      'quantity_produced': produced,
      'wastage': _p['wastage'],
      'recorded_by': _op.actorId,
      'recorded_at': _at,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });

    for (final recipe in _snapshot.rows('production_recipes')) {
      if (recipe['product_id'] != product) continue;
      final need =
          ((recipe['quantity_used'] as num) *
                  bags /
                  (recipe['per_bags'] as num))
              .round();
      final material = _snapshot.row(
        'stock_items',
        recipe['raw_material_item_id'] as String,
      );
      if (need > 0 && material != null) {
        _takeStock(
          material,
          need,
          'production_use',
          'Used in production run',
          runId: _op.opId,
        );
      }
    }

    final finished = _finishedItem(product);
    if (finished != null && produced > 0) {
      _addStock(
        finished,
        produced,
        'stock_in',
        'Produced — production run',
        expiry: _p['expiry_date'] as String?,
        runId: _op.opId,
      );
    }
  }

  void _customer() {
    _snapshot.rows('customers').add({
      'id': _p['id'],
      'tenant_id': _tenantId,
      'name': _p['name'],
      'phone': _p['phone'],
      'area': _p['area'],
      'credit_limit': _p['credit_limit'] ?? 0,
      'balance': 0,
      'last_payment_date': null,
      'local_op_id': _op.opId,
    });
  }

  void _stockIn() {
    final item = _snapshot.row('stock_items', _p['item_id'] as String);
    if (item == null) return;
    _addStock(
      item,
      _p['quantity'] as int,
      'stock_in',
      _p['note'] as String?,
      expiry: _p['expiry_date'] as String?,
    );
  }

  void _stockCount() {
    final item = _snapshot.row('stock_items', _p['item_id'] as String);
    if (item == null) return;
    final delta = (_p['new_count'] as int) - (item['quantity_on_hand'] as int);
    final note = _p['note'] as String?;
    if (delta < 0) {
      _takeStock(item, -delta, 'adjustment', note);
    } else if (delta > 0) {
      _addStock(item, delta, 'adjustment', note);
    } else {
      _movement(item, 'adjustment', 0, note);
    }
    _snapshot.lastStockCountAt = _op.recordedAt;
  }

  void _loadOut() {
    final product = _productId(_p);
    final bags = _p['bags_loaded'] as int;
    _snapshot.rows('load_outs').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'date_time': _at,
      'driver_id': _p['driver_id'],
      'vehicle_id': _p['vehicle_id'],
      ..._productFields(product),
      'bags_loaded': bags,
      'status': 'on_road',
      'note': _p['note'],
      'bags_sold': null,
      'bags_returned': null,
      'bags_damaged': null,
      'cash_returned': null,
      'settled_at': null,
      'discrepancy_note': null,
      'sale_id': null,
      'recorded_by': _op.actorId,
      'local_op_id': _op.opId,
    });
    final item = _finishedItem(product);
    if (item != null) {
      _takeStock(item, bags, 'stock_out', 'Loaded for distribution');
    }
  }

  void _driverReturn() {
    final id = (_p['load_out_id'] ?? _p['load_out_op_id']) as String?;
    final loadOut = id == null ? null : _snapshot.row('load_outs', id);
    if (loadOut == null) return;
    final returned = _p['bags_returned'] as int;
    final sold = _p['bags_sold'] as int;
    loadOut
      ..['status'] = 'settled'
      ..['bags_sold'] = sold
      ..['bags_returned'] = returned
      ..['bags_damaged'] = _p['bags_damaged']
      ..['cash_returned'] = _p['cash_returned']
      ..['settled_at'] = _at
      ..['discrepancy_note'] = _p['discrepancy_note'];

    final product = loadOut['product_id'] as String;
    final item = _finishedItem(product);
    if (item != null && returned > 0) {
      _addStock(item, returned, 'stock_in', 'Returned from load-out — unsold');
    }

    final unitPrice = _p['unit_price'] as num?;
    if (sold > 0 && unitPrice != null) {
      final total = sold * unitPrice;
      final paid = (_p['amount_paid'] as num?) ?? total;
      final saleId = '${_op.opId}-sale';
      _sale(
        id: saleId,
        customerType: (_p['customer_type'] as String?) ?? 'walk_in',
        customerName: _p['customer_name'] as String?,
        total: total,
        amountPaid: paid,
        paymentMethod: (_p['payment_method'] as String?) ?? 'cash',
        balance: total - paid,
        lines: const [],
        paidChannel: _p['paid_channel'] as String?,
        noteSuffix: ' (distribution trip)',
      );
      final sale = _snapshot.row('sales', saleId)!;
      (sale['sale_lines'] as List).add({
        'id': _childId(),
        'tenant_id': _tenantId,
        'sale_id': saleId,
        ..._productFields(product),
        'quantity': sold,
        'unit_price': unitPrice,
      });
      loadOut['sale_id'] = saleId;
    }
  }

  // ---------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------

  /// The product a record names: its `product_id`, or — for records
  /// queued before products were per organization — its old product key.
  String _productId(Map<String, dynamic> record) {
    final id = record['product_id'] as String?;
    if (id != null) return id;
    for (final product in _snapshot.rows('products')) {
      if (product['legacy_key'] == record['product']) {
        return product['id'] as String;
      }
    }
    return record['product'] as String? ?? '';
  }

  /// `product_id` plus the embedded name/unit, as the app's queries return.
  Map<String, dynamic> _productFields(String productId) {
    final product = _snapshot.row('products', productId);
    return {
      'product_id': productId,
      'products': {'name': product?['name'], 'unit': product?['unit']},
    };
  }

  Map<String, dynamic>? _finishedItem(String productId) {
    for (final item in _snapshot.rows('stock_items')) {
      if (item['product_id'] == productId) return item;
    }
    return null;
  }

  Map<String, dynamic>? _customerNamed(String name) {
    for (final customer in _snapshot.rows('customers')) {
      if (customer['name'] == name) return customer;
    }
    return null;
  }

  void _movement(
    Map<String, dynamic> item,
    String type,
    int quantity,
    String? note, {
    String? saleId,
    String? runId,
  }) {
    _snapshot.rows('stock_movements').add({
      'id': _childId(),
      'tenant_id': _tenantId,
      'item_id': item['id'],
      'type': type,
      'quantity': quantity,
      'note': note,
      'by_whom': _op.actorId,
      'at': _at,
      'batch_id': null,
      'production_run_id': runId,
      'sale_id': saleId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    item['quantity_on_hand'] = (item['quantity_on_hand'] as int) + quantity;
  }

  /// Oldest batches first, like consume_stock_fifo. Stock may go below
  /// zero (the server allows that for records made offline).
  void _takeStock(
    Map<String, dynamic> item,
    int quantity,
    String type,
    String? note, {
    String? saleId,
    String? runId,
  }) {
    final batches =
        _snapshot
            .rows('stock_batches')
            .where(
              (b) =>
                  b['item_id'] == item['id'] &&
                  (b['quantity_remaining'] as int) > 0,
            )
            .toList()
          ..sort(
            (a, b) => (a['received_at'] as String).compareTo(
              b['received_at'] as String,
            ),
          );
    var remaining = quantity;
    for (final batch in batches) {
      if (remaining <= 0) break;
      final take = remaining < (batch['quantity_remaining'] as int)
          ? remaining
          : batch['quantity_remaining'] as int;
      batch['quantity_remaining'] = (batch['quantity_remaining'] as int) - take;
      remaining -= take;
    }
    _movement(item, type, -quantity, note, saleId: saleId, runId: runId);
  }

  void _addStock(
    Map<String, dynamic> item,
    int quantity,
    String type,
    String? note, {
    String? expiry,
    String? runId,
  }) {
    _snapshot.rows('stock_batches').add({
      'id': _childId(),
      'tenant_id': _tenantId,
      'item_id': item['id'],
      'received_at': _at,
      'expiry_date': expiry,
      'quantity_received': quantity,
      'quantity_remaining': quantity,
      'production_run_id': runId,
      'note': note,
      'created_by': _op.actorId,
      'local_op_id': _op.opId,
    });
    _movement(item, type, quantity, note, runId: runId);
  }

  void _ledger(
    Map<String, dynamic> customer,
    String type,
    num amount,
    String? note, {
    String? saleId,
    String? date,
  }) {
    _snapshot.rows('ledger_entries').add({
      'id': _childId(),
      'tenant_id': _tenantId,
      'customer_id': customer['id'],
      'type': type,
      'amount': amount,
      'date': date ?? _today,
      'note': note,
      'sale_id': saleId,
      'recorded_by': _op.actorId,
      'customers': {'name': customer['name']},
      'local_op_id': _op.opId,
    });
  }

  void _cash(
    String direction,
    String source,
    num amount,
    String method,
    String? note, {
    String? saleId,
    String? dateTime,
  }) {
    _snapshot.rows('cash_entries').add({
      'id': _childId(),
      'tenant_id': _tenantId,
      'date_time': dateTime ?? _at,
      'direction': direction,
      'source': source,
      'amount': amount,
      'method': method,
      'note': note,
      'sale_id': saleId,
      'recorded_by': _op.actorId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    final signed = direction == 'money_in' ? amount : -amount;
    if (method == 'cash') {
      _snapshot.cashInHand += signed;
    } else {
      _snapshot.bankBalance += signed;
    }
  }
}
