import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/network_error.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../subscriptions/data/models/subscription.dart';
import '../models/device_registration.dart';
import '../models/offline_credential.dart';
import '../models/offline_member.dart';
import '../models/offline_snapshot.dart';
import '../models/outbox_operation.dart';
import '../repositories/device_sync_api.dart';
import '../repositories/offline_store.dart';
import 'local_bookkeeping.dart';

/// Everything about offline use on this device, for the UI.
@immutable
class OfflineState {
  const OfflineState({
    this.loaded = false,
    this.device,
    this.snapshot,
    this.outbox = const [],
    this.syncing = false,
    this.lastSyncedAt,
    this.lastSyncError,
    this.revision = 0,
  });

  final bool loaded;
  final DeviceRegistration? device;
  final OfflineSnapshot? snapshot;

  /// Records not yet accepted by the server, oldest first.
  final List<OutboxOperation> outbox;
  final bool syncing;
  final DateTime? lastSyncedAt;

  /// Why the last sync couldn't finish, when it wasn't just "no internet".
  final String? lastSyncError;

  /// Bumped on every change to the data, so screens reload.
  final int revision;

  List<OutboxOperation> get pending =>
      outbox.where((op) => op.status == OperationStatus.pending).toList();
  List<OutboxOperation> get rejected =>
      outbox.where((op) => op.status == OperationStatus.rejected).toList();

  bool isReadyFor(String tenantId) =>
      device?.tenantId == tenantId && snapshot != null;

  OfflineState copyWith({
    bool? loaded,
    DeviceRegistration? device,
    OfflineSnapshot? snapshot,
    List<OutboxOperation>? outbox,
    bool? syncing,
    DateTime? lastSyncedAt,
    String? Function()? lastSyncError,
    bool clearDevice = false,
  }) {
    return OfflineState(
      loaded: loaded ?? this.loaded,
      device: clearDevice ? null : device ?? this.device,
      snapshot: clearDevice ? null : snapshot ?? this.snapshot,
      outbox: outbox ?? this.outbox,
      syncing: syncing ?? this.syncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastSyncError: lastSyncError == null
          ? this.lastSyncError
          : lastSyncError(),
      revision: revision + 1,
    );
  }
}

/// Why signing in without internet didn't work.
enum OfflineSignInFailure {
  /// No organization's data on this device.
  deviceNotSetUp,

  /// Phone/email and PIN/password don't match anyone here.
  incorrect,

  /// Their access to the organization was switched off.
  deactivated,

  /// They haven't signed in online since offline sign-in was turned on,
  /// so this device has no way to check their PIN yet.
  noOfflineCheck,
}

sealed class OfflineSignInResult {
  const OfflineSignInResult();
}

final class OfflineSignInSuccess extends OfflineSignInResult {
  const OfflineSignInSuccess(this.member);
  final OfflineMember member;
}

final class OfflineSignInRefused extends OfflineSignInResult {
  const OfflineSignInRefused(this.reason);
  final OfflineSignInFailure reason;
}

/// Runs offline use on this device: set-up, records made offline, and
/// syncing them (send in order, then download fresh data and re-apply
/// whatever is still waiting).
class OfflineController extends StateNotifier<OfflineState> {
  OfflineController({
    required OfflineStore store,
    required DeviceSyncApi api,
    Random? random,
  }) : _store = store,
       _api = api,
       _random = random ?? Random.secure(),
       super(const OfflineState());

  final OfflineStore _store;
  final DeviceSyncApi _api;
  final Random _random;

  /// Records sent per request.
  static const _pushBatchSize = 50;

  /// Download fresh data at least this often while there's internet.
  static const refreshEvery = Duration(minutes: 5);

  Map<String, String> _serverIds = {};
  Future<void> _queue = Future.value();
  Future<void>? _syncInProgress;
  bool _syncAgain = false;

  /// Runs [action] after every earlier queued change, so a record made
  /// during a sync is never lost from the device's copy.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void>? _loading;

  /// Completes once the device's offline data has been read.
  Future<void> get ready => _loading ??= load();

  Future<void> load() async {
    try {
      final device = await _store.readDevice();
      final snapshot = device == null ? null : await _store.readSnapshot();
      final outbox = await _store.readOutbox();
      _serverIds = await _store.readServerIds();
      state = state.copyWith(
        loaded: true,
        device: device,
        snapshot: snapshot,
        outbox: outbox,
      );
    } catch (error) {
      // No local storage available (e.g. tests): online-only, as before.
      debugPrint('Offline storage unavailable: $error');
      state = state.copyWith(loaded: true);
    }
  }

  // ---------------------------------------------------------------------
  // Set-up
  // ---------------------------------------------------------------------

  /// Owner/Admin, online: registers this device and downloads the
  /// organization's data.
  Future<void> setUp({required String tenantId, required String name}) async {
    final registered = await _api.registerDevice(
      tenantId: tenantId,
      name: name,
    );
    final device = DeviceRegistration(
      deviceId: registered.id,
      deviceKey: registered.key,
      tenantId: tenantId,
      deviceName: name,
      setUpAt: DateTime.now(),
    );
    final snapshot = await _api.pull(device);
    await _store.saveDevice(device);
    await _store.saveSnapshot(snapshot);
    state = state.copyWith(
      device: device,
      snapshot: snapshot,
      lastSyncedAt: DateTime.now(),
      lastSyncError: () => null,
    );
  }

  /// Removes the organization's data from this device. Refused while
  /// records are still waiting, so nothing is lost.
  Future<void> turnOff() async {
    if (state.outbox.isNotEmpty) {
      throw StateError(
        'Records made on this device haven\'t all synced yet. Sync them first.',
      );
    }
    await _store.clear();
    _serverIds = {};
    state = state.copyWith(clearDevice: true, outbox: const []);
  }

  // ---------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------

  /// Saves a record on this device (it survives restarts), applies it to
  /// the device's data straight away, then tries to send it.
  Future<OutboxOperation> record({
    required OperationType type,
    required Map<String, dynamic> payload,
    required StaffUser actor,
  }) async {
    final operation = await _serialized(() async {
      final snapshot = state.snapshot;
      if (snapshot == null) {
        throw StateError('This device is not set up for offline use.');
      }
      final subscription = snapshot.subscription;
      if (subscription != null &&
          !Subscription.fromJson(subscription).canRecordAt(DateTime.now())) {
        throw StateError(subscriptionEndedOnDeviceMessage);
      }
      final operation = OutboxOperation(
        opId: newId(),
        seq: _nextSeq(),
        type: type,
        actorId: actor.id,
        actorName: actor.fullName,
        recordedAt: DateTime.now(),
        payload: payload,
      );
      await _store.saveOperation(operation);
      LocalBookkeeping.apply(snapshot, operation);
      await _store.saveSnapshot(snapshot);
      state = state.copyWith(outbox: [...state.outbox, operation]);
      return operation;
    });
    unawaited(sync());
    return operation;
  }

  int _nextSeq() => state.outbox.isEmpty ? 1 : state.outbox.last.seq + 1;

  /// A random UUID v4 (record ids made on this device).
  String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// The device's data right now (null when not set up).
  OfflineSnapshot? get currentSnapshot => state.snapshot;

  /// Records not yet accepted by the server.
  List<OutboxOperation> get currentOutbox => state.outbox;

  /// The server's id for a record made on this device, once it synced.
  String? serverIdFor(String localId) => _serverIds[localId];

  // ---------------------------------------------------------------------
  // Syncing
  // ---------------------------------------------------------------------

  /// Sends waiting records, then downloads fresh data. Safe to call any
  /// time: a call made while a sync is running gets one more round
  /// straight after it (e.g. for a record made meanwhile), and waits for
  /// that round too.
  Future<void> sync() {
    if (state.device == null) return Future.value();
    final running = _syncInProgress;
    if (running != null) {
      _syncAgain = true;
      return running;
    }
    final run = () async {
      do {
        _syncAgain = false;
        await _sync();
      } while (_syncAgain);
    }();
    _syncInProgress = run;
    return run.whenComplete(() => _syncInProgress = null);
  }

  /// Syncs when records are waiting or the data is getting old.
  Future<void> syncIfDue() {
    final last = state.lastSyncedAt;
    final stale =
        last == null || DateTime.now().difference(last) >= refreshEvery;
    return state.pending.isNotEmpty || stale ? sync() : Future.value();
  }

  Future<void> _sync() async {
    final device = state.device!;
    state = state.copyWith(syncing: true);
    try {
      final stopped = await _push(device);
      final fresh = await _api.pull(device);
      await _serialized(() async {
        final outbox = await _store.readOutbox();
        for (final op in outbox) {
          if (op.status == OperationStatus.pending) {
            LocalBookkeeping.apply(fresh, op);
          }
        }
        await _store.saveSnapshot(fresh);
        state = state.copyWith(
          snapshot: fresh,
          outbox: outbox,
          syncing: false,
          lastSyncedAt: DateTime.now(),
          lastSyncError: () => stopped,
        );
      });
    } catch (error) {
      await _refreshOutbox();
      state = state.copyWith(
        syncing: false,
        // No internet is normal offline; only report real problems.
        lastSyncError: () => isNetworkError(error)
            ? null
            : readableErrorMessage(error) ??
                  "Couldn't sync. It will try again automatically.",
      );
    }
  }

  /// Sends pending records in order. Returns the server's reason if it
  /// stopped part-way.
  Future<String?> _push(DeviceRegistration device) async {
    while (true) {
      final batch = (await _store.readOutbox())
          .where((op) => op.status == OperationStatus.pending)
          .take(_pushBatchSize)
          .toList();
      if (batch.isEmpty) return null;

      final result = await _api.push(device, batch);
      for (final outcome in result.results) {
        if (outcome.applied) {
          await _store.deleteOperation(outcome.opId);
          if (outcome.serverId != null) {
            _serverIds[outcome.opId] = outcome.serverId!;
          }
        } else {
          final op = batch.firstWhere((o) => o.opId == outcome.opId);
          await _store.saveOperation(
            op.copyWith(status: OperationStatus.rejected, error: outcome.error),
          );
        }
      }
      await _store.saveServerIds(_serverIds);
      await _refreshOutbox();

      if (result.stoppedReason != null) return result.stoppedReason;
      if (result.results.length < batch.length) return null;
    }
  }

  /// Reloads the waiting records from storage, in turn with any record
  /// being saved, so the list on screen never misses a new one.
  Future<void> _refreshOutbox() => _serialized(() async {
    state = state.copyWith(outbox: await _store.readOutbox());
  });

  /// Sends a refused record again (e.g. after the staff member was
  /// reactivated).
  Future<void> retry(String opId) async {
    await _serialized(() async {
      final op = state.outbox.firstWhere((o) => o.opId == opId);
      await _store.saveOperation(op.copyWith(status: OperationStatus.pending));
      state = state.copyWith(outbox: await _store.readOutbox());
    });
    await sync();
  }

  /// Gives up on a refused record. It stays in the server's log.
  Future<void> discard(String opId) async {
    await _serialized(() async {
      await _store.deleteOperation(opId);
      state = state.copyWith(outbox: await _store.readOutbox());
    });
    await sync();
  }

  // ---------------------------------------------------------------------
  // Signing in
  // ---------------------------------------------------------------------

  /// Checks [secret] against the downloaded offline sign-in check.
  Future<OfflineSignInResult> signIn({
    required String identifier,
    required String secret,
  }) async {
    final snapshot = state.snapshot;
    if (state.device == null || snapshot == null) {
      return const OfflineSignInRefused(OfflineSignInFailure.deviceNotSetUp);
    }
    final member = snapshot.members
        .where((m) => m.isIdentifiedBy(identifier))
        .firstOrNull;
    if (member == null) {
      return const OfflineSignInRefused(OfflineSignInFailure.incorrect);
    }
    final credential = member.credential;
    if (credential == null) {
      return const OfflineSignInRefused(OfflineSignInFailure.noOfflineCheck);
    }
    final matches = await compute(_credentialMatches, (
      credential: credential,
      secret: secret,
    ));
    if (!matches) {
      return const OfflineSignInRefused(OfflineSignInFailure.incorrect);
    }
    if (!member.isActive) {
      return const OfflineSignInRefused(OfflineSignInFailure.deactivated);
    }
    return OfflineSignInSuccess(member);
  }

  /// After an online sign-in: stores a fresh offline sign-in check for
  /// this person, so they can sign in on set-up devices without internet.
  Future<void> saveCredential(String secret) async {
    final credential = await compute(OfflineCredential.create, secret);
    await _api.saveMyOfflineCredential(credential);
  }

  /// The signed-in member as this device knows them (role, active), if
  /// it holds that organization.
  OfflineMember? memberOnDevice(String userId) =>
      state.snapshot?.member(userId);
}

bool _credentialMatches(({OfflineCredential credential, String secret}) args) =>
    args.credential.matches(args.secret);
