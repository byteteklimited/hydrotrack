import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/debts/data/models/customer.dart';

Customer _buildCustomer({
  num balance = 0,
  num creditLimit = 100000,
  DateTime? lastPaymentDate,
}) {
  return Customer(
    id: 'c1',
    name: 'Blessing Stores',
    phone: '08011112222',
    area: 'Kubwa',
    creditLimit: creditLimit,
    balance: balance,
    lastPaymentDate: lastPaymentDate,
  );
}

void main() {
  group('Customer JSON', () {
    test('fromJson handles a null last_payment_date', () {
      final customer = Customer.fromJson({
        'id': 'c1',
        'name': 'Blessing Stores',
        'phone': '08011112222',
        'area': 'Kubwa',
        'credit_limit': 100000,
        'balance': 0,
        'last_payment_date': null,
      });
      expect(customer.lastPaymentDate, isNull);
    });

    test('round-trips through fromJson(toJson(x))', () {
      final customer = _buildCustomer(
        balance: 5000,
        lastPaymentDate: DateTime(2026, 3, 1),
      );
      final roundTripped = Customer.fromJson(customer.toJson());
      expect(roundTripped.id, customer.id);
      expect(roundTripped.name, customer.name);
      expect(roundTripped.creditLimit, customer.creditLimit);
      expect(roundTripped.balance, customer.balance);
      expect(roundTripped.lastPaymentDate, customer.lastPaymentDate);
    });
  });

  group('isOverCreditLimit', () {
    test('true once balance reaches the credit limit', () {
      final customer = _buildCustomer(balance: 100000, creditLimit: 100000);
      expect(customer.isOverCreditLimit, isTrue);
    });

    test('false while balance is below the credit limit', () {
      final customer = _buildCustomer(balance: 50000, creditLimit: 100000);
      expect(customer.isOverCreditLimit, isFalse);
    });
  });

  group('isOverdue', () {
    test('false when nothing is owed', () {
      final customer = _buildCustomer(balance: 0);
      expect(customer.isOverdue, isFalse);
    });

    test('true when money is owed and no payment has ever been made', () {
      final customer = _buildCustomer(balance: 5000, lastPaymentDate: null);
      expect(customer.isOverdue, isTrue);
    });

    test('false when the last payment was recent', () {
      final customer = _buildCustomer(
        balance: 5000,
        lastPaymentDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(customer.isOverdue, isFalse);
    });

    test('true once the last payment is old enough', () {
      final customer = _buildCustomer(
        balance: 5000,
        lastPaymentDate: DateTime.now().subtract(const Duration(days: 60)),
      );
      expect(customer.isOverdue, isTrue);
    });
  });

  group('isInCredit', () {
    test('false when nothing is owed and nothing is overpaid', () {
      final customer = _buildCustomer(balance: 0);
      expect(customer.isInCredit, isFalse);
    });

    test('false while a balance is still owed', () {
      final customer = _buildCustomer(balance: 5000);
      expect(customer.isInCredit, isFalse);
    });

    test('true once the balance goes negative (overpaid)', () {
      final customer = _buildCustomer(balance: -27000);
      expect(customer.isInCredit, isTrue);
    });
  });

  group('copyWith', () {
    test('updates balance without touching other fields', () {
      final customer = _buildCustomer(balance: 1000);
      final updated = customer.copyWith(balance: 2000);
      expect(updated.balance, 2000);
      expect(updated.creditLimit, customer.creditLimit);
      expect(updated.name, customer.name);
    });
  });
}
