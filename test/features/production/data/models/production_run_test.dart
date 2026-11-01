import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/production/data/models/production_run.dart';

import '../../../../helpers/test_products.dart';

void main() {
  group('ProductionRun JSON', () {
    test('fromJson reads the joined profiles.full_name as recordedBy', () {
      final run = ProductionRun.fromJson({
        'id': 'pr1',
        'date': '2026-03-05',
        'shift': 'morning',
        'machine': 'Machine 2',
        'operator_name': 'Amina Yusuf',
        ...sachet50cl.toRecordJson(),
        'quantity_produced': 1200,
        'wastage': 20,
        'profiles': {'full_name': 'Amina Yusuf'},
        'recorded_at': '2026-03-05T07:30:00.000Z',
      });
      expect(run.recordedBy, 'Amina Yusuf');
      expect(run.shift, ProductionShift.morning);
      expect(run.quantityProduced, 1200);
      expect(run.wastage, 20);
    });

    test('fromJson falls back to "Unknown" when profiles is missing', () {
      final run = ProductionRun.fromJson({
        'id': 'pr1',
        'date': '2026-03-05',
        'shift': 'afternoon',
        'machine': 'Machine 1',
        'operator_name': 'Someone',
        ...bottle75cl.toRecordJson(),
        'quantity_produced': 500,
        'wastage': 0,
        'profiles': null,
        'recorded_at': '2026-03-05T13:00:00.000Z',
      });
      expect(run.recordedBy, 'Unknown');
    });

    test('toJson writes recorded_by as a flat string, not nested', () {
      final run = ProductionRun(
        id: 'pr1',
        date: DateTime(2026, 3, 5),
        shift: ProductionShift.morning,
        machine: 'Machine 2',
        operatorName: 'Amina Yusuf',
        product: sachet50cl,
        quantityProduced: 1200,
        wastage: 20,
        recordedBy: 'Amina Yusuf',
        recordedAt: DateTime(2026, 3, 5, 7, 30),
      );
      expect(run.toJson()['recorded_by'], 'Amina Yusuf');
      expect(run.toJson()['shift'], 'morning');
    });
  });

  group('wastagePercent', () {
    ProductionRun buildRun({
      required int quantityProduced,
      required int wastage,
    }) {
      return ProductionRun(
        id: 'pr1',
        date: DateTime(2026, 3, 5),
        shift: ProductionShift.morning,
        machine: 'Machine 1',
        operatorName: 'Amina Yusuf',
        product: sachet50cl,
        quantityProduced: quantityProduced,
        wastage: wastage,
        recordedBy: 'Amina Yusuf',
        recordedAt: DateTime(2026, 3, 5, 7, 30),
      );
    }

    test('is wastage as a percentage of everything processed', () {
      final run = buildRun(quantityProduced: 980, wastage: 20);
      expect(run.wastagePercent, 2.0);
    });

    test('is zero when nothing was processed at all', () {
      final run = buildRun(quantityProduced: 0, wastage: 0);
      expect(run.wastagePercent, 0);
    });

    test('is zero when there was no wastage', () {
      final run = buildRun(quantityProduced: 1000, wastage: 0);
      expect(run.wastagePercent, 0);
    });
  });
}
