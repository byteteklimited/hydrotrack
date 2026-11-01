import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/inventory/data/models/stock_batch.dart';

StockBatch _buildBatch({
  int quantityReceived = 1000,
  int quantityRemaining = 500,
  DateTime? expiryDate,
}) {
  return StockBatch(
    id: 'batch1',
    itemId: 'item1',
    receivedAt: DateTime(2026, 1, 1),
    quantityReceived: quantityReceived,
    quantityRemaining: quantityRemaining,
    expiryDate: expiryDate,
  );
}

void main() {
  group('StockBatch JSON', () {
    test('round-trips through fromJson', () {
      final batch = StockBatch.fromJson({
        'id': 'batch1',
        'item_id': 'item1',
        'received_at': '2026-01-01T00:00:00.000Z',
        'quantity_received': 1000,
        'quantity_remaining': 500,
        'expiry_date': '2026-06-01',
        'production_run_id': 'run1',
      });
      expect(batch.quantityReceived, 1000);
      expect(batch.quantityRemaining, 500);
      expect(batch.expiryDate, DateTime(2026, 6, 1));
      expect(batch.productionRunId, 'run1');
    });

    test('fromJson handles a null expiry_date and production_run_id', () {
      final batch = StockBatch.fromJson({
        'id': 'batch1',
        'item_id': 'item1',
        'received_at': '2026-01-01T00:00:00.000Z',
        'quantity_received': 1000,
        'quantity_remaining': 500,
        'expiry_date': null,
        'production_run_id': null,
      });
      expect(batch.expiryDate, isNull);
      expect(batch.productionRunId, isNull);
    });
  });

  group('isDepleted', () {
    test('true once nothing remains', () {
      expect(_buildBatch(quantityRemaining: 0).isDepleted, isTrue);
    });

    test('false while something remains', () {
      expect(_buildBatch(quantityRemaining: 1).isDepleted, isFalse);
    });
  });

  group('expiryStatus', () {
    test('is none when there is no expiry date at all', () {
      expect(_buildBatch().expiryStatus, BatchExpiryStatus.none);
    });

    test('is none when the expiry date is well in the future', () {
      final farFuture = DateTime.now().add(const Duration(days: 365));
      expect(
        _buildBatch(expiryDate: farFuture).expiryStatus,
        BatchExpiryStatus.none,
      );
    });

    test('is expiringSoon once inside the warning window', () {
      final soon = DateTime.now().add(const Duration(days: 10));
      expect(
        _buildBatch(expiryDate: soon).expiryStatus,
        BatchExpiryStatus.expiringSoon,
      );
    });

    test('is expired once the date has passed', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(
        _buildBatch(expiryDate: past).expiryStatus,
        BatchExpiryStatus.expired,
      );
    });
  });
}
