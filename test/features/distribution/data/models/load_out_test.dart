import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/constants/product_catalog.dart';
import 'package:hydrotrack/features/distribution/data/models/load_out.dart';

LoadOut _buildLoadOut({
  LoadOutStatus status = LoadOutStatus.onRoad,
  int bagsLoaded = 100,
}) {
  return LoadOut(
    id: 'lo1',
    dateTime: DateTime(2026, 3, 5, 7),
    driverId: 'd1',
    vehicleId: 'v1',
    product: ProductType.sachet50cl,
    bagsLoaded: bagsLoaded,
    status: status,
  );
}

void main() {
  group('loadOutStatusFromDb / dbValue', () {
    test('maps every status both ways', () {
      for (final status in LoadOutStatus.values) {
        expect(loadOutStatusFromDb(status.dbValue), status);
      }
    });

    test('throws for an unrecognized status', () {
      expect(() => loadOutStatusFromDb('in_transit'), throwsArgumentError);
    });
  });

  group('LoadOut JSON', () {
    test(
      'fromJson handles a settled trip with all optional fields present',
      () {
        final loadOut = LoadOut.fromJson({
          'id': 'lo1',
          'date_time': '2026-03-05T07:00:00.000Z',
          'driver_id': 'd1',
          'vehicle_id': 'v1',
          'product': 'sachet50cl',
          'bags_loaded': 100,
          'status': 'settled',
          'note': null,
          'bags_sold': 80,
          'bags_returned': 15,
          'bags_damaged': 5,
          'cash_returned': 32000,
          'settled_at': '2026-03-05T18:00:00.000Z',
          'discrepancy_note': null,
        });
        expect(loadOut.status, LoadOutStatus.settled);
        expect(loadOut.bagsSold, 80);
        expect(loadOut.bagsReturned, 15);
        expect(loadOut.bagsDamaged, 5);
        expect(loadOut.settledAt, DateTime.parse('2026-03-05T18:00:00.000Z'));
      },
    );

    test('fromJson handles an on-road trip with no settlement fields yet', () {
      final loadOut = LoadOut.fromJson({
        'id': 'lo1',
        'date_time': '2026-03-05T07:00:00.000Z',
        'driver_id': 'd1',
        'vehicle_id': 'v1',
        'product': 'sachet50cl',
        'bags_loaded': 100,
        'status': 'on_road',
        'note': null,
        'bags_sold': null,
        'bags_returned': null,
        'bags_damaged': null,
        'cash_returned': null,
        'settled_at': null,
        'discrepancy_note': null,
      });
      expect(loadOut.status, LoadOutStatus.onRoad);
      expect(loadOut.settledAt, isNull);
      expect(loadOut.bagsSold, isNull);
    });

    test('round-trips through fromJson(toJson(x))', () {
      final loadOut = _buildLoadOut();
      final roundTripped = LoadOut.fromJson(loadOut.toJson());
      expect(roundTripped.id, loadOut.id);
      expect(roundTripped.product, loadOut.product);
      expect(roundTripped.bagsLoaded, loadOut.bagsLoaded);
      expect(roundTripped.status, loadOut.status);
    });
  });

  group('expectedCashFromLoad', () {
    test('scales with bags loaded', () {
      final loadOut = _buildLoadOut(bagsLoaded: 200);
      expect(loadOut.expectedCashFromLoad, greaterThan(0));
      final doubled = _buildLoadOut(bagsLoaded: 400);
      expect(doubled.expectedCashFromLoad, loadOut.expectedCashFromLoad * 2);
    });
  });
}
