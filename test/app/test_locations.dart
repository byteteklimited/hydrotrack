import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydrotrack/features/locations/data/models/location.dart';
import 'package:hydrotrack/features/locations/data/providers/location_providers.dart';

const testLocation = Location(
  id: 'main',
  name: 'Main factory',
  kind: LocationKind.factory,
  isMain: true,
);

/// App tests work at one location, without a server.
final testLocationOverrides = <Override>[
  locationOptionsProvider.overrideWith(
    (ref) async => const LocationOptions(allowed: [testLocation]),
  ),
  allLocationsProvider.overrideWith((ref) async => const [testLocation]),
];
