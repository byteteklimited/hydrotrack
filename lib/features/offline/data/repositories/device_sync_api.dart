import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/device_registration.dart';
import '../models/offline_credential.dart';
import '../models/offline_snapshot.dart';
import '../models/outbox_operation.dart';
import '../models/registered_device.dart';

/// What the server said about one sent record.
class OperationResult {
  const OperationResult({
    required this.opId,
    required this.applied,
    this.serverId,
    this.error,
  });

  final String opId;
  final bool applied;

  /// The id the record got on the server (sales, runs, load-outs).
  final String? serverId;

  /// Why it was refused, when not [applied].
  final String? error;

  factory OperationResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    return OperationResult(
      opId: json['op_id'] as String,
      applied: json['status'] == 'applied',
      serverId: result?['id'] as String?,
      error: json['error'] as String?,
    );
  }
}

class PushResult {
  const PushResult({required this.results, this.stoppedReason});

  final List<OperationResult> results;

  /// Set when the server stopped part-way (e.g. the device was switched
  /// off); the remaining records weren't looked at.
  final String? stoppedReason;
}

/// The server side of offline use: setting devices up, downloading the
/// organization's data, sending records made offline.
abstract class DeviceSyncApi {
  /// Owner/Admin, online. Returns the new device's id and key.
  Future<({String id, String key})> registerDevice({
    required String tenantId,
    required String name,
  });

  Future<List<RegisteredDevice>> fetchDevices(String tenantId);
  Future<void> revokeDevice({
    required String tenantId,
    required String deviceId,
  });

  Future<OfflineSnapshot> pull(DeviceRegistration device);
  Future<PushResult> push(
    DeviceRegistration device,
    List<OutboxOperation> operations,
  );

  /// Stores the signed-in person's offline sign-in check.
  Future<void> saveMyOfflineCredential(OfflineCredential credential);
}

class SupabaseDeviceSyncApi implements DeviceSyncApi {
  SupabaseClient get _client => Supabase.instance.client;

  static const _function = 'device-sync';

  @override
  Future<({String id, String key})> registerDevice({
    required String tenantId,
    required String name,
  }) async {
    final row =
        await _client.rpc(
              'register_device',
              params: {'p_tenant_id': tenantId, 'p_name': name},
            )
            as Map<String, dynamic>;
    return (id: row['id'] as String, key: row['key'] as String);
  }

  @override
  Future<List<RegisteredDevice>> fetchDevices(String tenantId) async {
    final rows = await _client
        .from('devices')
        .select('id, name, created_at, last_seen_at, revoked_at')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows as List)
        RegisteredDevice.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> revokeDevice({
    required String tenantId,
    required String deviceId,
  }) {
    return _client.rpc(
      'revoke_device',
      params: {'p_tenant_id': tenantId, 'p_device_id': deviceId},
    );
  }

  @override
  Future<OfflineSnapshot> pull(DeviceRegistration device) async {
    final response = await _client.functions.invoke(
      _function,
      body: {'action': 'pull', 'device_key': device.deviceKey},
    );
    return OfflineSnapshot.fromPull(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  @override
  Future<PushResult> push(
    DeviceRegistration device,
    List<OutboxOperation> operations,
  ) async {
    final response = await _client.functions.invoke(
      _function,
      body: {
        'action': 'push',
        'device_key': device.deviceKey,
        'operations': [for (final op in operations) op.toSyncJson()],
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return PushResult(
      results: [
        for (final result in data['results'] as List)
          OperationResult.fromJson(Map<String, dynamic>.from(result as Map)),
      ],
      stoppedReason: data['stopped'] as String?,
    );
  }

  @override
  Future<void> saveMyOfflineCredential(OfflineCredential credential) {
    return _client.rpc(
      'set_my_offline_credential',
      params: {
        'p_salt': credential.salt,
        'p_hash': credential.hash,
        'p_iterations': credential.iterations,
      },
    );
  }
}
