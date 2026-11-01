import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../local/database_factory.dart';
import '../models/device_registration.dart';
import '../models/offline_snapshot.dart';
import '../models/outbox_operation.dart';

/// Where this device keeps its offline data: the set-up, the downloaded
/// organization data, records waiting to be sent, and which server id
/// each sent record got.
abstract class OfflineStore {
  Future<DeviceRegistration?> readDevice();
  Future<void> saveDevice(DeviceRegistration device);

  Future<OfflineSnapshot?> readSnapshot();
  Future<void> saveSnapshot(OfflineSnapshot snapshot);

  /// Oldest first.
  Future<List<OutboxOperation>> readOutbox();
  Future<void> saveOperation(OutboxOperation operation);
  Future<void> deleteOperation(String opId);

  /// Record id on this device (its operation id) → id on the server.
  Future<Map<String, String>> readServerIds();
  Future<void> saveServerIds(Map<String, String> ids);

  /// Removes everything (turning offline use off on this device).
  Future<void> clear();
}

/// [OfflineStore] on sembast: IndexedDB in browsers, a file elsewhere.
class SembastOfflineStore implements OfflineStore {
  SembastOfflineStore({Future<Database>? database})
    : _database = database ?? openOfflineDatabase(_databaseName);

  static const _databaseName = 'hydrotrack_offline.db';
  static const _deviceKey = 'device';
  static const _snapshotKey = 'snapshot';
  static const _serverIdsKey = 'server_ids';

  final Future<Database> _database;
  final _meta = StoreRef<String, Object?>('meta');
  final _outbox = StoreRef<String, Map<String, Object?>>('outbox');

  /// Values read from sembast are read-only; this returns an editable copy.
  static Map<String, dynamic> _editable(Object value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  Future<Map<String, dynamic>?> _readMeta(String key) async {
    final value = await _meta.record(key).get(await _database);
    return value == null ? null : _editable(value);
  }

  @override
  Future<DeviceRegistration?> readDevice() async {
    final json = await _readMeta(_deviceKey);
    return json == null ? null : DeviceRegistration.fromJson(json);
  }

  @override
  Future<void> saveDevice(DeviceRegistration device) async {
    await _meta.record(_deviceKey).put(await _database, device.toJson());
  }

  @override
  Future<OfflineSnapshot?> readSnapshot() async {
    final json = await _readMeta(_snapshotKey);
    return json == null ? null : OfflineSnapshot.fromJson(json);
  }

  @override
  Future<void> saveSnapshot(OfflineSnapshot snapshot) async {
    await _meta
        .record(_snapshotKey)
        .put(await _database, _editable(snapshot.toJson()));
  }

  @override
  Future<List<OutboxOperation>> readOutbox() async {
    final records = await _outbox.find(
      await _database,
      finder: Finder(sortOrders: [SortOrder('seq')]),
    );
    return [
      for (final record in records)
        OutboxOperation.fromJson(_editable(record.value)),
    ];
  }

  @override
  Future<void> saveOperation(OutboxOperation operation) async {
    await _outbox
        .record(operation.opId)
        .put(await _database, _editable(operation.toJson()));
  }

  @override
  Future<void> deleteOperation(String opId) async {
    await _outbox.record(opId).delete(await _database);
  }

  @override
  Future<Map<String, String>> readServerIds() async {
    final json = await _readMeta(_serverIdsKey);
    return json == null ? {} : json.cast<String, String>();
  }

  @override
  Future<void> saveServerIds(Map<String, String> ids) async {
    await _meta.record(_serverIdsKey).put(await _database, ids);
  }

  @override
  Future<void> clear() async {
    final database = await _database;
    await _meta.drop(database);
    await _outbox.drop(database);
  }
}
