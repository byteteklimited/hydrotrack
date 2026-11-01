import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../models/location.dart';
import '../repositories/locations_repository.dart';

/// The header that tells the server which location a request is for
/// (migration 0029). It only narrows what someone may see.
const locationHeader = 'x-location-id';

/// Sends [locationId] with every request from now on (none when null).
void applyLocationHeader(String? locationId) {
  try {
    final client = Supabase.instance.client;
    final headers = {...client.headers}..remove(locationHeader);
    if (locationId != null && locationId.isNotEmpty) {
      headers[locationHeader] = locationId;
    }
    client.headers = headers;
  } catch (_) {
    // Supabase isn't set up (tests): nothing to send.
  }
}

final locationsRepositoryProvider = Provider<LocationsRepository>(
  (ref) => SupabaseLocationsRepository(ref.watch(currentTenantIdProvider)),
);

/// Where the signed-in person may work in the current organization.
class LocationOptions {
  const LocationOptions({
    required this.allowed,
    this.rememberedId,
    this.fixedByDevice = false,
  });

  final List<Location> allowed;
  final String? rememberedId;

  /// A device set up for offline use always works at its own location.
  final bool fixedByDevice;
}

final locationOptionsProvider = FutureProvider<LocationOptions>((ref) async {
  ref.watch(currentTenantIdProvider);
  final offline = ref.watch(offlineContextProvider);
  if (offline != null) {
    final deviceLocation = offline.snapshot.location;
    return LocationOptions(
      fixedByDevice: true,
      allowed: [
        deviceLocation == null
            // Downloaded before locations existed: the server still knows.
            ? const Location(id: '', name: '', kind: LocationKind.factory)
            : Location.fromJson(deviceLocation),
      ],
    );
  }
  final repository = ref.watch(locationsRepositoryProvider);
  final role = ref.watch(authStateProvider.select((user) => user?.role));
  final active = [
    for (final location in await repository.fetchLocations())
      if (location.isActive) location,
  ];
  final List<Location> allowed;
  if (role?.isAdminLevel ?? false) {
    allowed = active;
  } else {
    final mine = await repository.fetchMyLocationIds();
    allowed = [
      for (final location in active)
        if (mine.contains(location.id)) location,
    ];
  }
  String? remembered;
  try {
    remembered = await repository.rememberedLocationId();
  } catch (_) {}
  return LocationOptions(allowed: allowed, rememberedId: remembered);
});

/// Picked this session (see [chooseLocation]).
final chosenLocationIdProvider = StateProvider<String?>((ref) => null);

/// The location the app is working in: the chosen one, else the one used
/// last on this device, else the first allowed. Null while loading or when
/// the person isn't assigned anywhere.
final currentLocationProvider = Provider<Location?>((ref) {
  final options = ref.watch(locationOptionsProvider).valueOrNull;
  if (options == null || options.allowed.isEmpty) return null;
  Location? byId(String? id) =>
      options.allowed.where((location) => location.id == id).firstOrNull;
  return byId(ref.watch(chosenLocationIdProvider)) ??
      byId(options.rememberedId) ??
      options.allowed.first;
});

typedef DataScope = ({String tenantId, String? locationId});

/// What every data provider is keyed on: switching organization or
/// location reloads everything. Also points requests at the location —
/// before any repository built from it makes one.
final dataScopeProvider = Provider<DataScope>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  final locationId = ref.watch(currentLocationProvider)?.id;
  applyLocationHeader(locationId);
  return (tenantId: tenantId, locationId: locationId);
});

/// Switches to [location] and remembers it on this device.
Future<void> chooseLocation(WidgetRef ref, Location location) async {
  ref.read(chosenLocationIdProvider.notifier).state = location.id;
  try {
    await ref.read(locationsRepositoryProvider).rememberLocation(location.id);
  } catch (_) {}
}

/// Leaving an organization: stop sending its location.
void forgetLocation(WidgetRef ref) {
  ref.read(chosenLocationIdProvider.notifier).state = null;
  applyLocationHeader(null);
}

/// Member id → their locations (owners and admins only).
final locationAssignmentsProvider =
    FutureProvider.autoDispose<Map<String, Set<String>>>((ref) {
      return ref.watch(locationsRepositoryProvider).fetchAssignments();
    });

/// Every location, for the Locations screen and transfer destinations.
final allLocationsProvider = FutureProvider<List<Location>>((ref) {
  return ref.watch(locationsRepositoryProvider).fetchLocations();
});

class LocationsActionController extends ActionController {
  LocationsActionController(this._ref);

  final Ref _ref;

  Future<bool> saveLocation({
    required String name,
    required LocationKind kind,
    String? id,
    bool? isActive,
  }) async {
    final done = await guard(() async {
      await _ref
          .read(locationsRepositoryProvider)
          .saveLocation(name: name, kind: kind, id: id, isActive: isActive);
      _ref
        ..invalidate(allLocationsProvider)
        ..invalidate(locationOptionsProvider);
      return true;
    });
    return done ?? false;
  }

  Future<bool> setAssignments(String locationId, Set<String> memberIds) async {
    final done = await guard(() async {
      await _ref
          .read(locationsRepositoryProvider)
          .setAssignments(locationId, memberIds);
      _ref.invalidate(locationAssignmentsProvider);
      return true;
    });
    return done ?? false;
  }
}

final locationsActionControllerProvider =
    StateNotifierProvider.autoDispose<
      LocationsActionController,
      AsyncValue<void>
    >((ref) => LocationsActionController(ref));
