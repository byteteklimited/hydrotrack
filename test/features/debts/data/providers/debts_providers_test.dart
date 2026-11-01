import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/customer.dart';
import 'package:hydrotrack/features/debts/data/providers/debts_providers.dart';

Customer _customer({required String id, required num balance}) => Customer(
  id: id,
  name: id,
  phone: '08000000000',
  area: 'Kaduna',
  creditLimit: 50000,
  balance: balance,
);

void main() {
  group('debtsSummaryProvider — invariant #4: Money outside == sum of '
      'positive Customer balances only', () {
    test(
      'totalOutside sums only positive balances, never negative ones',
      () async {
        final customers = [
          _customer(id: 'owing-1', balance: 20000),
          _customer(id: 'owing-2', balance: 3000),
          _customer(id: 'in-credit', balance: -10000),
          _customer(id: 'settled', balance: 0),
        ];

        final container = ProviderContainer(
          overrides: [customersProvider.overrideWith((ref) async => customers)],
        );
        addTearDown(container.dispose);

        await container.read(customersProvider.future);
        final summary = container.read(debtsSummaryProvider).value!;

        expect(summary.totalOutside, 23000);
        expect(summary.customersOwing, 2);
      },
    );

    test('totalCredit is the positive magnitude of negative balances, '
        'never counted as negative debt', () async {
      final customers = [
        _customer(id: 'in-credit-1', balance: -10000),
        _customer(id: 'in-credit-2', balance: -3000),
        _customer(id: 'owing', balance: 5000),
      ];

      final container = ProviderContainer(
        overrides: [customersProvider.overrideWith((ref) async => customers)],
      );
      addTearDown(container.dispose);

      await container.read(customersProvider.future);
      final summary = container.read(debtsSummaryProvider).value!;

      expect(summary.totalCredit, 13000);
      expect(summary.customersInCredit, 2);
      // The two figures never overlap — the same customer can't be
      // both owing and in credit at once.
      expect(summary.totalOutside, 5000);
    });
  });
}
