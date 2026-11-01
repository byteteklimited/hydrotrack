import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/constants/product_catalog.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';
import 'package:hydrotrack/features/sales/data/models/sale_line.dart';

Sale _buildSale({required num total, required num amountPaid}) {
  return Sale(
    id: 's1',
    dateTime: DateTime(2026, 3, 5),
    customerType: CustomerType.walkIn,
    lines: const [
      SaleLine(product: ProductType.sachet50cl, quantity: 10, unitPrice: 400),
    ],
    total: total,
    amountPaid: amountPaid,
    paymentMethod: PaymentMethod.cash,
    balance: total - amountPaid,
    recordedBy: 'Ngozi Okafor',
  );
}

void main() {
  group('customerTypeFromDb / dbValue', () {
    test('maps every customer type both ways', () {
      for (final type in CustomerType.values) {
        expect(customerTypeFromDb(type.dbValue), type);
      }
    });

    test('throws for an unrecognized customer type', () {
      expect(() => customerTypeFromDb('wholesale'), throwsArgumentError);
    });
  });

  group('Sale JSON', () {
    test(
      'fromJson reads nested sale_lines and the joined profiles.full_name',
      () {
        final sale = Sale.fromJson({
          'id': 's1',
          'date_time': '2026-03-05T09:14:00.000Z',
          'customer_type': 'distributor',
          'customer_name': 'Blessing Stores',
          'sale_lines': [
            {'product': 'sachet50cl', 'quantity': 40, 'unit_price': 400},
          ],
          'total': 16000,
          'amount_paid': 16000,
          'payment_method': 'cash',
          'balance': 0,
          'profiles': {'full_name': 'Ngozi Okafor'},
        });
        expect(sale.customerType, CustomerType.distributor);
        expect(sale.lines, hasLength(1));
        expect(sale.recordedBy, 'Ngozi Okafor');
        expect(sale.totalBags, 40);
      },
    );

    test('fromJson falls back to "Unknown" when profiles is missing', () {
      final sale = Sale.fromJson({
        'id': 's1',
        'date_time': '2026-03-05T09:14:00.000Z',
        'customer_type': 'walk_in',
        'customer_name': null,
        'sale_lines': <Map<String, dynamic>>[],
        'total': 0,
        'amount_paid': 0,
        'payment_method': 'cash',
        'balance': 0,
        'profiles': null,
      });
      expect(sale.recordedBy, 'Unknown');
      expect(sale.customerName, isNull);
    });

    test(
      'fromJson reads void fields, including the joined voiding staff name',
      () {
        final sale = Sale.fromJson({
          'id': 's1',
          'date_time': '2026-03-05T09:14:00.000Z',
          'customer_type': 'walk_in',
          'customer_name': null,
          'sale_lines': <Map<String, dynamic>>[],
          'total': 8000,
          'amount_paid': 8000,
          'payment_method': 'cash',
          'balance': 0,
          'profiles': {'full_name': 'Ngozi Okafor'},
          'voided_at': '2026-03-06T10:00:00.000Z',
          'voided_by_profile': {'full_name': 'Admin User'},
          'void_reason': 'Entered twice by mistake',
        });
        expect(sale.isVoided, isTrue);
        expect(sale.voidedBy, 'Admin User');
        expect(sale.voidReason, 'Entered twice by mistake');
      },
    );

    test('isVoided is false when voided_at is absent', () {
      final sale = Sale.fromJson({
        'id': 's1',
        'date_time': '2026-03-05T09:14:00.000Z',
        'customer_type': 'walk_in',
        'customer_name': null,
        'sale_lines': <Map<String, dynamic>>[],
        'total': 8000,
        'amount_paid': 8000,
        'payment_method': 'cash',
        'balance': 0,
        'profiles': null,
      });
      expect(sale.isVoided, isFalse);
    });

    test('toJson writes customer_type using the Postgres snake_case value', () {
      final sale = Sale(
        id: 's1',
        dateTime: DateTime(2026, 3, 5, 9, 14),
        customerType: CustomerType.walkIn,
        lines: const [
          SaleLine(
            product: ProductType.sachet50cl,
            quantity: 10,
            unitPrice: 400,
          ),
        ],
        total: 4000,
        amountPaid: 4000,
        paymentMethod: PaymentMethod.cash,
        balance: 0,
        recordedBy: 'Ngozi Okafor',
      );
      expect(sale.toJson()['customer_type'], 'walk_in');
    });
  });

  group('totalBags', () {
    test('sums quantity across every line', () {
      final sale = Sale(
        id: 's1',
        dateTime: DateTime(2026, 3, 5),
        customerType: CustomerType.walkIn,
        lines: const [
          SaleLine(
            product: ProductType.sachet50cl,
            quantity: 10,
            unitPrice: 400,
          ),
          SaleLine(
            product: ProductType.bottle75cl,
            quantity: 5,
            unitPrice: 150,
          ),
        ],
        total: 4750,
        amountPaid: 4750,
        paymentMethod: PaymentMethod.cash,
        balance: 0,
        recordedBy: 'Ngozi Okafor',
      );
      expect(sale.totalBags, 15);
    });
  });

  group('paymentStatus', () {
    test('is paid once the balance is zero', () {
      final sale = _buildSale(total: 4000, amountPaid: 4000);
      expect(sale.paymentStatus, SalePaymentStatus.paid);
    });

    test('is paid when the balance is negative (overpaid)', () {
      final sale = _buildSale(total: 4000, amountPaid: 4500);
      expect(sale.paymentStatus, SalePaymentStatus.paid);
    });

    test('is partPaid when something was paid but a balance remains', () {
      final sale = _buildSale(total: 4000, amountPaid: 1000);
      expect(sale.paymentStatus, SalePaymentStatus.partPaid);
    });

    test('is onCredit when nothing was paid at all', () {
      final sale = _buildSale(total: 4000, amountPaid: 0);
      expect(sale.paymentStatus, SalePaymentStatus.onCredit);
    });
  });
}
