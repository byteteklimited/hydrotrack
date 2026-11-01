import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/locations/data/models/location.dart';
import 'package:hydrotrack/features/locations/data/models/stock_transfer.dart';
import 'package:hydrotrack/features/locations/data/providers/location_providers.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';
import 'package:hydrotrack/features/organizations/data/providers/organization_providers.dart';

const _main = Location(
  id: 'main',
  name: 'Main factory',
  kind: LocationKind.factory,
  isMain: true,
);
const _depot = Location(
  id: 'depot',
  name: 'Kano depot',
  kind: LocationKind.depot,
);

Future<ProviderContainer> _container({String? remembered}) async {
  final container = ProviderContainer(
    overrides: [
      currentOrganizationProvider.overrideWith(
        (ref) => const Organization(id: 'org', name: 'Sunny Water'),
      ),
      locationOptionsProvider.overrideWith(
        (ref) async => LocationOptions(
          allowed: const [_main, _depot],
          rememberedId: remembered,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(locationOptionsProvider.future);
  return container;
}

void main() {
  test('the first allowed location is used until another is picked', () async {
    final container = await _container();
    expect(container.read(currentLocationProvider), _main);
    expect(container.read(dataScopeProvider), (
      tenantId: 'org',
      locationId: 'main',
    ));
    container.read(chosenLocationIdProvider.notifier).state = 'depot';
    expect(container.read(dataScopeProvider).locationId, 'depot');
  });

  test('the location used last on this device comes back', () async {
    final container = await _container(remembered: 'depot');
    expect(container.read(currentLocationProvider), _depot);
  });

  test('a location no longer allowed is never used', () async {
    final container = await _container(remembered: 'closed');
    container.read(chosenLocationIdProvider.notifier).state = 'other-org';
    expect(container.read(currentLocationProvider), _main);
  });

  test('a transfer reads where it goes and whether it waits here', () {
    final transfer = StockTransfer.fromJson({
      'id': 't',
      'from_location': 'Main factory',
      'to_location': 'Kano depot',
      'incoming': true,
      'status': 'sent',
      'note': null,
      'sent_at': '2026-11-01T08:00:00Z',
      'received_at': null,
      'sent_by': 'Sam Store',
      'items': [
        {'name': '50cl Sachet', 'unit': 'bags', 'quantity': 30},
      ],
    });
    expect(transfer.toReceive, isTrue);
    expect(transfer.items.single.quantity, 30);
    expect(LocationKind.fromDb('depot'), LocationKind.depot);
  });
}
