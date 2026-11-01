import '../../../../core/utils/formatters.dart';
import '../../../finance/data/repositories/cash_count_repository.dart';
import '../../../organizations/data/models/water_limits.dart';
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
      case OperationType.cashCount:
        _cashCount();
      case OperationType.waterTest:
        _waterTest();
      case OperationType.sanitationCheck:
        _sanitationCheck();
      case OperationType.diesel:
        _diesel();
      case OperationType.maintenanceDone:
        _maintenanceDone();
      case OperationType.breakdown:
        _breakdown();
      case OperationType.breakdownEnd:
        _breakdownEnd();
      case OperationType.attendance:
        _daily('attendance', 'status', 'marked_by', 'marked_at');
      case OperationType.bagCounts:
        _daily('bag_counts', 'bags', 'entered_by', 'entered_at');
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
    _snapshot.totalRevenue += total;
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
      'batch_numbers': <String>[],
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
            'unit_cost':
                _finishedItem(_productId(line))?['average_cost'] as num? ?? 0,
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
    _postExpense(
      id: _op.opId,
      date: _p['date'] as String,
      category: _p['category'] as String,
      description: _p['description'] as String?,
      amount: _p['amount'] as num,
      method: _p['method'] as String,
    );
  }

  /// An expense and its cash out, as record_expense / post_machine_expense
  /// make them. Returns the expense id (null when there's nothing to post).
  String? _postExpense({
    required String id,
    required String date,
    required String category,
    required String? description,
    required num amount,
    required String? method,
  }) {
    if (amount <= 0 || method == null) return null;
    _snapshot.rows('expenses').add({
      'id': id,
      'tenant_id': _tenantId,
      'date': date,
      'category': category,
      'description': description,
      'amount': amount,
      'method': method,
      'recorded_by': _op.actorId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    _cash(
      'money_out',
      category == 'wages' ? 'wages' : 'expense',
      amount,
      method,
      description,
      dateTime: '${date}T00:00:00Z',
    );
    return id;
  }

  /// Like the server's link_run_machine: the machine with that name.
  String? _machineIdNamed(String? name) {
    final wanted = name?.trim().toLowerCase();
    for (final machine in _snapshot.rows('machines')) {
      if ((machine['name'] as String).trim().toLowerCase() == wanted) {
        return machine['id'] as String;
      }
    }
    return null;
  }

  String _machineName(String? id) =>
      (id == null ? null : _snapshot.row('machines', id)?['name'] as String?) ??
      'Machine';

  void _diesel() {
    final date = _p['date'] as String;
    final litres = _p['litres'] as num;
    final expense = _postExpense(
      id: _childId(),
      date: date,
      category: 'fuel_diesel',
      description:
          'Diesel for ${_machineName(_p['machine_id'] as String?)}: '
          '${formatPlain(litres)} litres',
      amount: _p['cost'] as num,
      method: _p['method'] as String?,
    );
    _snapshot.rows('diesel_logs').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'machine_id': _p['machine_id'],
      'date': date,
      'litres': litres,
      'cost': _p['cost'],
      'run_hours': _p['run_hours'],
      'expense_id': expense,
      'note': _p['note'],
      'recorded_by': _op.actorId,
      'created_at': _at,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
  }

  void _maintenanceDone() {
    final task = _snapshot.row('maintenance_tasks', _p['task_id'] as String);
    if (task == null) return;
    final doneOn = _p['done_on'] as String;
    final cost = _p['cost'] as num? ?? 0;
    final expense = _postExpense(
      id: _childId(),
      date: doneOn,
      category: 'maintenance',
      description:
          '${_machineName(task['machine_id'] as String?)}: ${task['name']}',
      amount: cost,
      method: _p['method'] as String?,
    );
    _snapshot.rows('maintenance_logs').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'task_id': task['id'],
      'machine_id': task['machine_id'],
      'done_on': doneOn,
      'cost': cost,
      'expense_id': expense,
      'note': _p['note'],
      'done_by': _op.actorId,
      'created_at': _at,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    final last = task['last_done_on'] as String?;
    if (last == null || last.compareTo(doneOn) < 0) {
      task['last_done_on'] = doneOn;
    }
  }

  void _breakdown() {
    _snapshot.rows('breakdowns').add({
      'id': _p['id'],
      'tenant_id': _tenantId,
      'machine_id': _p['machine_id'],
      'started_at': _p['started_at'],
      'ended_at': null,
      'cause': _p['cause'],
      'repair_cost': 0,
      'note': null,
      'reported_by': _op.actorId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
  }

  void _breakdownEnd() {
    final breakdown = _snapshot.row('breakdowns', _p['breakdown_id'] as String);
    if (breakdown == null) return;
    final endedAt = _p['ended_at'] as String;
    final cost = _p['repair_cost'] as num? ?? 0;
    final expense = _postExpense(
      id: _childId(),
      date: DateTime.parse(
        endedAt,
      ).toLocal().toIso8601String().split('T').first,
      category: 'maintenance',
      description:
          'Repair: ${_machineName(breakdown['machine_id'] as String?)} '
          '(${breakdown['cause']})',
      amount: cost,
      method: _p['method'] as String?,
    );
    breakdown
      ..['ended_at'] = endedAt
      ..['repair_cost'] = cost
      ..['expense_id'] = expense
      ..['note'] = _p['note'];
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
      'machine_id': _machineIdNamed(_p['machine'] as String?),
      'batch_number': null,
      'operator_name': _p['operator_name'],
      ..._productFields(product),
      'quantity_produced': produced,
      'wastage': _p['wastage'],
      'recorded_by': _op.actorId,
      'recorded_at': _at,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });

    num materialCost = 0;
    for (final recipe in _snapshot.rows('production_recipes')) {
      if (recipe['product_id'] != product) continue;
      final need =
          ((recipe['quantity_used'] as num) *
                  bags /
                  (recipe['per_bags'] as num))
              .round();
      final material = _recipeMaterial(recipe);
      if (need > 0 && material != null) {
        materialCost += need * (material['average_cost'] as num? ?? 0);
        _takeStock(
          material,
          need,
          'production_use',
          'Used in production run',
          runId: _op.opId,
        );
      }
    }

    _snapshot.row('production_runs', _op.opId)!['material_cost'] = materialCost;
    _snapshot.totalBagsProduced += produced;
    final finished = _finishedItem(product);
    if (finished != null && produced > 0) {
      _averageIn(finished, produced, materialCost / produced);
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

  void _cashCount() {
    final expected = localExpectedCash(_snapshot, _op.actorId, _op.recordedAt);
    _snapshot.rows('cash_counts').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'cashier_id': _op.actorId,
      'period_start': expected.since.toUtc().toIso8601String(),
      'counted_at': _at,
      'cash_in': expected.cashIn,
      'cash_out': expected.cashOut,
      'expected': expected.expected,
      'counted': _p['counted'],
      'note': _p['note'],
      'confirmed_at': null,
      'confirmed_by': null,
      'cashier': _recorder,
      'confirmer': null,
      'local_op_id': _op.opId,
    });
  }

  void _waterTest() {
    final ph = _p['ph'] as num;
    final tds = _p['tds'] as num;
    final chlorine = _p['chlorine'] as num;
    final problems = WaterLimits.fromTenantJson(
      _snapshot.organization,
    ).problems(ph: ph, tds: tds, chlorine: chlorine);
    _snapshot.rows('water_tests').add({
      'id': _op.opId,
      'tenant_id': _tenantId,
      'date': _p['date'],
      'shift': _p['shift'],
      'tested_at': _at,
      'ph': ph,
      'tds': tds,
      'chlorine': chlorine,
      'passed': problems.isEmpty,
      'problems': problems,
      'note': _p['note'],
      'recorded_by': _op.actorId,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
  }

  /// Ticks replace that day's earlier ticks for the same items.
  void _sanitationCheck() {
    final date = _p['date'] as String;
    final rows = _snapshot.rows('sanitation_checks');
    for (final item in _p['items'] as List) {
      final tick = Map<String, dynamic>.from(item as Map);
      rows
        ..removeWhere(
          (row) => row['date'] == date && row['item_id'] == tick['item_id'],
        )
        ..add({
          'id': _childId(),
          'tenant_id': _tenantId,
          'date': date,
          'item_id': tick['item_id'],
          'done': tick['done'] ?? false,
          'note': tick['note'],
          'checked_by': _op.actorId,
          'checked_at': _at,
          'profiles': _recorder,
          'local_op_id': _op.opId,
        });
    }
  }

  /// Attendance or bag counts: one row per worker per day; entering a
  /// day again replaces it, as on the server.
  void _daily(String table, String field, String byColumn, String atColumn) {
    final date = _p['date'] as String;
    final rows = _snapshot.rows(table);
    for (final item in _p['entries'] as List) {
      final entry = Map<String, dynamic>.from(item as Map);
      rows
        ..removeWhere(
          (row) =>
              row['date'] == date && row['worker_id'] == entry['worker_id'],
        )
        ..add({
          'id': _childId(),
          'tenant_id': _tenantId,
          'worker_id': entry['worker_id'],
          'date': date,
          field: entry[field],
          byColumn: _op.actorId,
          atColumn: _at,
          'local_op_id': _op.opId,
        });
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
      'unit_cost': item['average_cost'] ?? 0,
      'profiles': _recorder,
      'local_op_id': _op.opId,
    });
    item['quantity_on_hand'] = (item['quantity_on_hand'] as int) + quantity;
  }

  /// Folds [quantity] at [unitCost] into the item's average cost, as the
  /// server does for priced stock in (migration 0021).
  void _averageIn(Map<String, dynamic> item, int quantity, num unitCost) {
    final onHand = (item['quantity_on_hand'] as int) > 0
        ? item['quantity_on_hand'] as int
        : 0;
    final average = item['average_cost'] as num? ?? 0;
    item['average_cost'] =
        (onHand * average + quantity * unitCost) / (onHand + quantity);
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
      if (saleId != null) _noteSaleBatch(saleId, batch);
    }
    _movement(item, type, -quantity, note, saleId: saleId, runId: runId);
  }

  /// This device's own row for a recipe's raw material: recipes may name
  /// another location's row, so it's matched by item_key, as the server's
  /// item_at_location does.
  Map<String, dynamic>? _recipeMaterial(Map<String, dynamic> recipe) {
    final id = recipe['raw_material_item_id'] as String;
    final direct = _snapshot.row('stock_items', id);
    if (direct != null) return direct;
    final key = (recipe['stock_items'] as Map?)?['item_key'] as String?;
    if (key == null) return null;
    for (final item in _snapshot.rows('stock_items')) {
      if (item['item_key'] == key) return item;
    }
    return null;
  }

  /// Like the server's note_sale_batch: the sale remembers the batch
  /// number of each production run its bags came from.
  void _noteSaleBatch(String saleId, Map<String, dynamic> batch) {
    final runId = batch['production_run_id'] as String?;
    final number = runId == null
        ? null
        : _snapshot.row('production_runs', runId)?['batch_number'] as String?;
    final sale = _snapshot.row('sales', saleId);
    if (number == null || sale == null) return;
    final numbers = (sale['batch_numbers'] as List? ?? const [])
        .cast<String>()
        .toList();
    if (!numbers.contains(number)) sale['batch_numbers'] = [...numbers, number];
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
      'created_at': _at,
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
