import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/ledger_entry.dart';

void main() {
  group('ledgerEntryTypeFromDb / dbValue', () {
    test('maps every type both ways, including the snake_case ones', () {
      for (final type in LedgerEntryType.values) {
        expect(ledgerEntryTypeFromDb(type.dbValue), type);
      }
      expect(
        ledgerEntryTypeFromDb('opening_balance'),
        LedgerEntryType.openingBalance,
      );
      expect(ledgerEntryTypeFromDb('write_off'), LedgerEntryType.writeOff);
    });

    test('throws for an unrecognized type', () {
      expect(() => ledgerEntryTypeFromDb('refund'), throwsArgumentError);
    });
  });

  group('LedgerEntryType.balanceDelta', () {
    test('sale adds the amount', () {
      expect(LedgerEntryType.sale.balanceDelta(5000), 5000);
    });

    test('payment, voided, and write-off all subtract the amount', () {
      expect(LedgerEntryType.payment.balanceDelta(5000), -5000);
      expect(LedgerEntryType.voided.balanceDelta(5000), -5000);
      expect(LedgerEntryType.writeOff.balanceDelta(5000), -5000);
    });

    test('opening balance applies its own sign — a positive amount adds '
        '(customer already owed), a negative one subtracts (they already '
        'had credit)', () {
      expect(LedgerEntryType.openingBalance.balanceDelta(5000), 5000);
      expect(LedgerEntryType.openingBalance.balanceDelta(-5000), -5000);
    });
  });

  group('LedgerEntry JSON', () {
    test('fromJson handles a null note', () {
      final entry = LedgerEntry.fromJson({
        'id': 'l1',
        'customer_id': 'c1',
        'type': 'payment',
        'amount': 15000,
        'date': '2026-03-05',
        'note': null,
      });
      expect(entry.note, isNull);
      expect(entry.type, LedgerEntryType.payment);
    });

    test('round-trips through fromJson(toJson(x))', () {
      final entry = LedgerEntry(
        id: 'l1',
        customerId: 'c1',
        type: LedgerEntryType.sale,
        amount: 24000,
        date: DateTime(2026, 3, 5),
        note: 'Sale — balance carried to account',
      );
      final roundTripped = LedgerEntry.fromJson(entry.toJson());
      expect(roundTripped.id, entry.id);
      expect(roundTripped.customerId, entry.customerId);
      expect(roundTripped.type, entry.type);
      expect(roundTripped.amount, entry.amount);
      expect(roundTripped.date, entry.date);
      expect(roundTripped.note, entry.note);
    });
  });

  group('ledgerWithRunningBalances', () {
    test('folds oldest-first entries into a running balance, newest first', () {
      final entries = [
        LedgerEntry(
          id: 'l1',
          customerId: 'c1',
          type: LedgerEntryType.sale,
          amount: 2000,
          date: DateTime(2026, 1, 1),
        ),
        LedgerEntry(
          id: 'l2',
          customerId: 'c1',
          type: LedgerEntryType.payment,
          amount: 29000,
          date: DateTime(2026, 1, 2),
        ),
      ];

      final result = ledgerWithRunningBalances(entries);

      // Newest first.
      expect(result[0].$1.id, 'l2');
      expect(result[0].$2, -27000);
      expect(result[1].$1.id, 'l1');
      expect(result[1].$2, 2000);
    });

    test('the most recent running balance equals the customer total balance '
        '— invariant #6: a customer statement must agree with Debts', () {
      // Same real numbers this project's Debts "take it to 10" step
      // already verified live against Supabase for Ummita Habib: one
      // ₦2,000 credit sale, then ₦29,000 paid against it.
      final entries = [
        LedgerEntry(
          id: 'l1',
          customerId: 'ummita',
          type: LedgerEntryType.sale,
          amount: 2000,
          date: DateTime(2026, 1, 1),
        ),
        LedgerEntry(
          id: 'l2',
          customerId: 'ummita',
          type: LedgerEntryType.payment,
          amount: 29000,
          date: DateTime(2026, 1, 2),
        ),
      ];

      const customerBalance = -27000; // 2000 - 29000

      final mostRecentRunningBalance = ledgerWithRunningBalances(
        entries,
      ).first.$2;

      expect(mostRecentRunningBalance, customerBalance);
    });

    test('returns an empty list for a customer with no history', () {
      expect(ledgerWithRunningBalances([]), isEmpty);
    });

    test('a negative opening balance (customer already had credit) folds in '
        'correctly alongside a later sale', () {
      final entries = [
        LedgerEntry(
          id: 'l1',
          customerId: 'c1',
          type: LedgerEntryType.openingBalance,
          amount: -10000,
          date: DateTime(2026, 1, 1),
        ),
        LedgerEntry(
          id: 'l2',
          customerId: 'c1',
          type: LedgerEntryType.sale,
          amount: 4000,
          date: DateTime(2026, 1, 5),
        ),
      ];

      final result = ledgerWithRunningBalances(entries);

      expect(result[0].$2, -6000); // -10000 + 4000
      expect(result[1].$2, -10000);
    });
  });
}
