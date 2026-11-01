import 'package:http/http.dart' as http;
import 'package:hydrotrack/features/offline/data/models/device_registration.dart';
import 'package:hydrotrack/features/offline/data/models/offline_credential.dart';
import 'package:hydrotrack/features/offline/data/models/offline_snapshot.dart';
import 'package:hydrotrack/features/offline/data/models/outbox_operation.dart';
import 'package:hydrotrack/features/offline/data/models/registered_device.dart';
import 'package:hydrotrack/features/offline/data/repositories/device_sync_api.dart';

const tenantId = 'tenant-1';
const sachetId = 'item-sachet';
const sachetProductId = 'product-sachet';
const nylonId = 'item-nylon';
const musaId = 'customer-musa';
const cashierId = 'user-cashier';
const testIterations = 1000;

/// A small organization as `device-sync` would download it: 100 sachet
/// bags in two batches, 10 nylon rolls (1 per 100 bags), one distributor,
/// a driver and a vehicle, two members (one with an offline check).
OfflineSnapshot sampleSnapshot({OfflineCredential? cashierCredential}) {
  return OfflineSnapshot.fromPull({
    'pulled_at': '2026-11-01T08:00:00Z',
    'history_since': '2026-08-03T08:00:00Z',
    'organization': {'id': tenantId, 'name': 'Sunny Water'},
    'members': [
      {
        'user_id': cashierId,
        'role': 'cashier',
        'is_active': true,
        'full_name': 'Carol Cashier',
        'phone': '2348031234567',
        'email': null,
        'credential': cashierCredential?.toJson(),
      },
      {
        'user_id': 'user-gone',
        'role': 'cashier',
        'is_active': false,
        'full_name': 'Gone Person',
        'phone': '2348099999999',
        'email': null,
        'credential': OfflineCredential.create(
          '111111',
          iterations: testIterations,
        ).toJson(),
      },
    ],
    'finance_position': {'cash_in_hand': 50000, 'bank_balance': 20000},
    'last_stock_count_at': null,
    'tables': {
      'products': [
        {
          'id': sachetProductId,
          'tenant_id': tenantId,
          'name': '50cl Sachet',
          'unit': 'bags',
          'walk_in_price': 400,
          'distributor_price': 380,
          'sort_order': 1,
          'archived_at': null,
          'legacy_key': 'sachet50cl',
        },
      ],
      'stock_items': [
        {
          'id': sachetId,
          'tenant_id': tenantId,
          'name': '50cl Sachet',
          'category': 'finished_goods',
          'unit': 'bags',
          'quantity_on_hand': 100,
          'reorder_level': 10,
          'product_id': sachetProductId,
          'products': {'name': '50cl Sachet', 'unit': 'bags'},
        },
        {
          'id': nylonId,
          'tenant_id': tenantId,
          'name': 'Nylon roll',
          'category': 'raw_material',
          'unit': 'rolls',
          'quantity_on_hand': 10,
          'reorder_level': 2,
          'product_id': null,
        },
      ],
      'stock_batches': [
        _batch('batch-old', sachetId, 60, '2026-10-01T08:00:00Z'),
        _batch('batch-new', sachetId, 40, '2026-10-20T08:00:00Z'),
        _batch('batch-nylon', nylonId, 10, '2026-10-01T08:00:00Z'),
      ],
      'production_recipes': [
        {
          'id': 'recipe-1',
          'tenant_id': tenantId,
          'product_id': sachetProductId,
          'raw_material_item_id': nylonId,
          'quantity_used': 1,
          'per_bags': 100,
          'stock_items': {'name': 'Nylon roll', 'unit': 'rolls'},
        },
      ],
      'customers': [
        {
          'id': musaId,
          'tenant_id': tenantId,
          'name': 'Musa Stores',
          'phone': '08031234567',
          'area': 'Kano',
          'credit_limit': 100000,
          'balance': 5000,
          'last_payment_date': '2026-10-01',
        },
      ],
      'drivers': [
        {
          'id': 'driver-1',
          'tenant_id': tenantId,
          'name': 'Yakubu',
          'phone': '080',
        },
      ],
      'vehicles': [
        {'id': 'vehicle-1', 'tenant_id': tenantId, 'name': 'Hilux'},
      ],
      'sales': <Map<String, dynamic>>[],
      'ledger_entries': <Map<String, dynamic>>[],
      'cash_entries': <Map<String, dynamic>>[],
      'expenses': <Map<String, dynamic>>[],
      'production_runs': <Map<String, dynamic>>[],
      'stock_movements': <Map<String, dynamic>>[],
      'load_outs': <Map<String, dynamic>>[],
      'sync_flags': <Map<String, dynamic>>[],
    },
  });
}

Map<String, dynamic> _batch(String id, String item, int qty, String at) => {
  'id': id,
  'tenant_id': tenantId,
  'item_id': item,
  'received_at': at,
  'expiry_date': null,
  'quantity_received': qty,
  'quantity_remaining': qty,
  'production_run_id': null,
};

Map<String, dynamic> salePayload({
  int bags = 10,
  num credit = 0,
  String paymentMethod = 'cash',
}) {
  return {
    'customer_type': credit > 0 ? 'distributor' : 'walk_in',
    'customer_name': credit > 0 ? 'Musa Stores' : null,
    'total': bags * 400,
    'amount_paid': bags * 400 - credit,
    'payment_method': credit > 0 ? 'credit' : paymentMethod,
    'balance': credit,
    'lines': [
      {
        'product_id': sachetProductId,
        'quantity': bags,
        'unit_price': 400,
        'list_price': 400,
      },
    ],
    'paid_channel': null,
  };
}

/// The server, faked: applies or refuses records, and can be "offline".
class FakeSyncApi implements DeviceSyncApi {
  FakeSyncApi(this.serverData);

  OfflineSnapshot serverData;
  bool offline = false;
  final refuse = <String>{};
  final received = <String>[];
  String? stopWith;

  void _connection() {
    if (offline) throw http.ClientException('Failed host lookup');
  }

  @override
  Future<({String id, String key})> registerDevice({
    required String tenantId,
    required String name,
  }) async {
    _connection();
    return (id: 'device-1', key: 'k' * 64);
  }

  @override
  Future<OfflineSnapshot> pull(DeviceRegistration device) async {
    _connection();
    return serverData.copy();
  }

  @override
  Future<PushResult> push(
    DeviceRegistration device,
    List<OutboxOperation> operations,
  ) async {
    _connection();
    if (stopWith != null) {
      return PushResult(results: const [], stoppedReason: stopWith);
    }
    final results = <OperationResult>[];
    for (final op in operations) {
      if (refuse.contains(op.type.dbValue)) {
        results.add(
          OperationResult(opId: op.opId, applied: false, error: 'Not allowed'),
        );
      } else {
        received.add(op.opId);
        results.add(
          OperationResult(
            opId: op.opId,
            applied: true,
            serverId: 'srv-${op.opId}',
          ),
        );
      }
    }
    return PushResult(results: results);
  }

  @override
  Future<void> saveMyOfflineCredential(OfflineCredential credential) async {}

  @override
  Future<List<RegisteredDevice>> fetchDevices(String tenantId) async =>
      const [];

  @override
  Future<void> revokeDevice({
    required String tenantId,
    required String deviceId,
  }) async {}
}
