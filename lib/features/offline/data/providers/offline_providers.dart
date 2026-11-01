import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/action_controller.dart';
import '../../../../core/utils/connectivity.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../auth/data/repositories/sign_in_result.dart';
import '../../../organizations/data/models/organization.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/registered_device.dart';
import '../models/sync_flag.dart';
import '../repositories/device_sync_api.dart';
import '../repositories/offline_store.dart';
import '../repositories/sync_flags_repository.dart';
import '../services/offline_context.dart';
import '../services/offline_controller.dart';

final offlineStoreProvider = Provider<OfflineStore>(
  (ref) => SembastOfflineStore(),
);

final deviceSyncApiProvider = Provider<DeviceSyncApi>(
  (ref) => SupabaseDeviceSyncApi(),
);

/// How often to check whether records are waiting or data is stale.
const _syncCheckEvery = Duration(minutes: 1);

/// Offline use on this device. Syncs when the connection comes back and
/// regularly while it's up.
final offlineControllerProvider =
    StateNotifierProvider<OfflineController, OfflineState>((ref) {
      final controller = OfflineController(
        store: ref.watch(offlineStoreProvider),
        api: ref.watch(deviceSyncApiProvider),
      );
      unawaited(controller.ready);

      ref.listen(isConnectedProvider, (previous, next) {
        if (next.valueOrNull == true) unawaited(controller.sync());
      });
      final timer = Timer.periodic(
        _syncCheckEvery,
        (_) => unawaited(controller.syncIfDue()),
      );
      ref.onDispose(timer.cancel);
      return controller;
    });

/// Set when this device holds the current organization's data: feature
/// repositories then work offline. Null otherwise (online only, as before).
final offlineContextProvider = Provider<OfflineContext?>((ref) {
  final state = ref.watch(offlineControllerProvider);
  final organization = ref.watch(currentOrganizationProvider);
  final user = ref.watch(authStateProvider);
  if (organization == null ||
      user == null ||
      !state.isReadyFor(organization.id)) {
    return null;
  }
  return OfflineContext(
    controller: ref.read(offlineControllerProvider.notifier),
    actor: user,
    isConnected: () => ref.read(isConnectedProvider).valueOrNull ?? true,
  );
});

/// Someone signed in without internet: their sign-in details, kept in
/// memory only, so the app can sign them in online in the background once
/// the connection is back (needed for online-only actions).
class OfflineSession {
  const OfflineSession({required this.identifier, required this.secret});

  final String identifier;
  final String secret;
}

final offlineSessionProvider = StateProvider<OfflineSession?>((ref) => null);

/// Watched while inside an organization: when the connection comes back
/// after an offline sign-in, signs the same person in online.
final onlineSessionRestorerProvider = Provider<void>((ref) {
  Future<void> restore() async {
    final session = ref.read(offlineSessionProvider);
    final auth = ref.read(authRepositoryProvider);
    if (session == null || auth.hasSession) return;
    final result = await auth.signIn(
      identifier: session.identifier,
      secret: session.secret,
    );
    if (result is SignInSuccess) {
      ref.read(offlineSessionProvider.notifier).state = null;
      rememberForOfflineSignIn(ref, session.secret);
      unawaited(ref.read(offlineControllerProvider.notifier).sync());
    }
  }

  ref.listen(isConnectedProvider, (previous, next) {
    if (next.valueOrNull == true) unawaited(restore());
  }, fireImmediately: true);
});

/// Opens the device's organization for the person still signed in on it
/// when the server can't be reached at start-up. False if this device
/// doesn't hold their organization (or their access was switched off).
Future<bool> enterDeviceOrganization(
  BuildContext context,
  WidgetRef ref,
) async {
  final offline = ref.read(offlineControllerProvider.notifier);
  await offline.ready;
  final userId = ref.read(authRepositoryProvider).signedInUserId;
  final snapshot = offline.currentSnapshot;
  final member = userId == null ? null : offline.memberOnDevice(userId);
  if (snapshot == null || member == null || !member.isActive) return false;
  if (!context.mounted) return false;

  ref.read(currentOrganizationProvider.notifier).state = Organization.fromJson(
    snapshot.organization,
  );
  ref.read(authStateProvider.notifier).state = member.toStaffUser();
  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  return true;
}

final syncFlagsRepositoryProvider = Provider<SyncFlagsRepository>((ref) {
  final remote = SupabaseSyncFlagsRepository(
    ref.watch(currentTenantIdProvider),
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineSyncFlagsRepository(remote, offline);
});

/// Records made offline still waiting for a manager to check them.
final openSyncFlagsProvider = FutureProvider<List<SyncFlag>>((ref) {
  return ref.watch(syncFlagsRepositoryProvider).fetchOpenFlags();
});

/// Marks a flagged record as checked.
class SyncFlagController extends ActionController {
  SyncFlagController(this._ref);

  final Ref _ref;

  Future<bool> markChecked(String flagId) async {
    final done = await guard(() async {
      await _ref.read(syncFlagsRepositoryProvider).markChecked(flagId);
      _ref.invalidate(openSyncFlagsProvider);
      return true;
    });
    return done ?? false;
  }
}

final syncFlagControllerProvider =
    StateNotifierProvider.autoDispose<SyncFlagController, AsyncValue<void>>(
      (ref) => SyncFlagController(ref),
    );

/// The organization's devices set up for offline use (Owner/Admin, online).
final registeredDevicesProvider = FutureProvider<List<RegisteredDevice>>((ref) {
  return ref
      .watch(deviceSyncApiProvider)
      .fetchDevices(ref.watch(currentTenantIdProvider));
});

/// Setting this device up, syncing it, turning it off, and switching off
/// other devices.
class OfflineDeviceController extends ActionController {
  OfflineDeviceController(this._ref);

  final Ref _ref;

  OfflineController get _offline =>
      _ref.read(offlineControllerProvider.notifier);

  Future<bool> setUp(String name) => _run(() async {
    await _offline.setUp(
      tenantId: _ref.read(currentTenantIdProvider),
      name: name,
    );
    _ref.invalidate(registeredDevicesProvider);
  });

  Future<bool> syncNow() => _run(_offline.sync);

  Future<bool> turnOff() => _run(_offline.turnOff);

  Future<bool> revoke(String deviceId) => _run(() async {
    await _ref
        .read(deviceSyncApiProvider)
        .revokeDevice(
          tenantId: _ref.read(currentTenantIdProvider),
          deviceId: deviceId,
        );
    _ref.invalidate(registeredDevicesProvider);
  });

  Future<bool> _run(Future<void> Function() action) async {
    final done = await guard(() async {
      await action();
      return true;
    });
    return done ?? false;
  }
}

final offlineDeviceControllerProvider =
    StateNotifierProvider.autoDispose<
      OfflineDeviceController,
      AsyncValue<void>
    >((ref) => OfflineDeviceController(ref));
