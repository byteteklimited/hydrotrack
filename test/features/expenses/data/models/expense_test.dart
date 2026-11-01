import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/expenses/data/models/expense.dart';

void main() {
  group('expenseCategoryFromDb / dbValue', () {
    test('maps every category both ways', () {
      for (final category in ExpenseCategory.values) {
        expect(expenseCategoryFromDb(category.dbValue), category);
      }
    });

    test('throws for an unrecognized category', () {
      expect(() => expenseCategoryFromDb('rent'), throwsArgumentError);
    });
  });

  group('Expense JSON', () {
    test('fromJson reads the joined profiles.full_name as recordedBy', () {
      final expense = Expense.fromJson({
        'id': 'e1',
        'date': '2026-03-05',
        'category': 'fuel_diesel',
        'description': 'Generator fuel',
        'amount': 18500,
        'method': 'cash',
        'profiles': {'full_name': 'Tunde Bakare'},
      });
      expect(expense.recordedBy, 'Tunde Bakare');
      expect(expense.category, ExpenseCategory.fuelDiesel);
      expect(expense.method, PaymentChannel.cash);
    });

    test('fromJson falls back to "Unknown" when profiles is missing', () {
      final expense = Expense.fromJson({
        'id': 'e1',
        'date': '2026-03-05',
        'category': 'other',
        'description': 'Misc',
        'amount': 1000,
        'method': 'cash',
        'profiles': null,
      });
      expect(expense.recordedBy, 'Unknown');
    });

    test('toJson writes recorded_by as a flat string, not nested', () {
      final expense = Expense(
        id: 'e1',
        date: DateTime(2026, 3, 5),
        category: ExpenseCategory.wages,
        description: 'Staff wages',
        amount: 50000,
        method: PaymentChannel.transfer,
        recordedBy: 'Tunde Bakare',
      );
      final json = expense.toJson();
      expect(json['recorded_by'], 'Tunde Bakare');
      expect(json['category'], 'wages');
    });
  });
}
