import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/finance/data/models/cash_entry.dart';

void main() {
  group('directionFromDb / sourceFromDb', () {
    test('maps every direction both ways', () {
      for (final direction in CashDirection.values) {
        expect(directionFromDb(direction.dbValue), direction);
      }
    });

    test('maps every source both ways', () {
      for (final source in CashSource.values) {
        expect(sourceFromDb(source.dbValue), source);
      }
    });

    test('throws for an unrecognized direction', () {
      expect(() => directionFromDb('sideways'), throwsArgumentError);
    });
  });

  group('CashEntry JSON', () {
    test('fromJson reads the joined profiles.full_name as recordedBy', () {
      final entry = CashEntry.fromJson({
        'id': 'ce1',
        'date_time': '2026-03-05T09:00:00.000Z',
        'direction': 'money_in',
        'source': 'sales',
        'amount': 24000,
        'method': 'cash',
        'note': null,
        'profiles': {'full_name': 'Ngozi Okafor'},
      });
      expect(entry.recordedBy, 'Ngozi Okafor');
      expect(entry.direction, CashDirection.moneyIn);
      expect(entry.source, CashSource.sales);
    });

    test('fromJson falls back to "Unknown" when profiles is missing', () {
      final entry = CashEntry.fromJson({
        'id': 'ce1',
        'date_time': '2026-03-05T09:00:00.000Z',
        'direction': 'money_out',
        'source': 'expense',
        'amount': 1000,
        'method': 'cash',
        'note': null,
        'profiles': null,
      });
      expect(entry.recordedBy, 'Unknown');
    });
  });

  group('signedAmount', () {
    test('positive for money in', () {
      final entry = CashEntry(
        id: 'ce1',
        dateTime: DateTime(2026, 3, 5),
        direction: CashDirection.moneyIn,
        source: CashSource.sales,
        amount: 24000,
        method: PaymentChannel.cash,
        recordedBy: 'Ngozi Okafor',
      );
      expect(entry.signedAmount, 24000);
    });

    test('negative for money out', () {
      final entry = CashEntry(
        id: 'ce1',
        dateTime: DateTime(2026, 3, 5),
        direction: CashDirection.moneyOut,
        source: CashSource.expense,
        amount: 18500,
        method: PaymentChannel.cash,
        recordedBy: 'Tunde Bakare',
      );
      expect(entry.signedAmount, -18500);
    });
  });
}
