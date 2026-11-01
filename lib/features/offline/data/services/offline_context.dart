import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/network_error.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../subscriptions/data/models/subscription.dart';
import '../models/offline_snapshot.dart';
import '../models/outbox_operation.dart';
import 'offline_controller.dart';

/// What a feature repository needs to work offline on a set-up device:
/// read from the server when it can (falling back to the device's data
/// when it can't be reached), save daily records on the device first, and
/// run online-only actions with a clear message when offline.
class OfflineContext {
  OfflineContext({
    required OfflineController controller,
    required this.actor,
    bool Function()? isConnected,
  }) : _controller = controller,
       _isConnected = isConnected ?? (() => true);

  final OfflineController _controller;
  final bool Function() _isConnected;

  /// Who records are made by.
  final StaffUser actor;

  /// The device's data as it is right now.
  OfflineSnapshot get snapshot => _controller.currentSnapshot!;

  /// True when the signed-in person has a live online session (someone
  /// who signed in offline doesn't, until they sign in online again).
  bool get hasOnlineSession {
    try {
      return Supabase.instance.client.auth.currentUser?.id == actor.id;
    } catch (_) {
      return false;
    }
  }

  bool get _canUseServer => _isConnected() && hasOnlineSession;

  /// Server data when reachable; otherwise this device's copy.
  Future<T> read<T>({
    required Future<T> Function() remote,
    required T Function(OfflineSnapshot snapshot) local,
  }) async {
    if (_canUseServer) {
      try {
        return await remote();
      } catch (error) {
        if (!isNetworkError(error)) rethrow;
      }
    }
    return local(snapshot);
  }

  /// A new id for something created on this device (e.g. a customer),
  /// which the server keeps.
  String newId() => _controller.newId();

  /// Saves a daily record on the device and sends it when possible.
  /// When the device's copy says the subscription has ended but there's
  /// internet, it refreshes first — the owner may have just renewed.
  Future<OutboxOperation> record(
    OperationType type,
    Map<String, dynamic> payload,
  ) async {
    final subscription = snapshot.subscription;
    if (subscription != null &&
        !Subscription.fromJson(subscription).canRecordAt(DateTime.now()) &&
        _isConnected()) {
      await _controller.sync();
    }
    return _controller.record(type: type, payload: payload, actor: actor);
  }

  /// Online-only actions (staff, settings, voids, edits, deletes).
  Future<T> online<T>(Future<T> Function() action) async {
    if (!hasOnlineSession) {
      throw const NeedsInternetException(
        'This needs you to be signed in online. Connect to the internet, '
        'sign out and sign in again, then try once more.',
      );
    }
    try {
      final result = await action();
      await _controller.sync();
      return result;
    } catch (error) {
      if (isNetworkError(error)) throw const NeedsInternetException();
      rethrow;
    }
  }

  /// The server's id for a record made on this device (sales, runs and
  /// load-outs get a new id there), or [localId] when it didn't come from
  /// this device. Throws [notSyncedMessage] while it hasn't synced.
  String serverIdOr(String localId, {required String notSyncedMessage}) {
    final row = _rowWithId(localId);
    final opId = row?['local_op_id'] as String?;
    if (opId == null) return localId;
    if (!isSynced(opId)) throw NeedsInternetException(notSyncedMessage);
    return _controller.serverIdFor(opId) ?? localId;
  }

  /// True once the server accepted the record [opId].
  bool isSynced(String opId) =>
      !_controller.currentOutbox.any((op) => op.opId == opId);

  Map<String, dynamic>? _rowWithId(String id) {
    for (final rows in snapshot.tables.values) {
      for (final row in rows) {
        if (row['id'] == id) return row;
      }
    }
    return null;
  }
}
