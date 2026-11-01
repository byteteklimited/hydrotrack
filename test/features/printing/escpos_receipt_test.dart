import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/business_header.dart';
import 'package:hydrotrack/features/printing/data/escpos_receipt.dart';
import 'package:hydrotrack/features/printing/data/receipt_printer_settings.dart';
import 'package:hydrotrack/features/sales/data/models/sale.dart';
import 'package:hydrotrack/features/sales/data/models/sale_line.dart';

import '../../helpers/test_products.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the printer receipt has the business, items, totals and a cut', () async {
    final sale = Sale(
      id: 's1',
      dateTime: DateTime(2026, 11, 1, 9, 30),
      customerType: CustomerType.distributor,
      customerName: 'Musa Stores',
      lines: const [SaleLine(product: sachet50cl, quantity: 10, unitPrice: 400)],
      total: 4000,
      amountPaid: 1000,
      paymentMethod: PaymentMethod.part,
      balance: 3000,
      recordedBy: 'Carol',
    );
    for (final paper in PaperWidth.values) {
      final bytes = await buildEscPosReceipt(
        sale,
        header: const BusinessHeader(
          name: 'Sunny Water',
          lines: ['12 Zoo Road, Kano'],
        ),
        paper: paper,
      );
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, contains('Sunny Water'));
      expect(text, contains('12 Zoo Road, Kano'));
      expect(text, contains('Musa Stores'));
      expect(text, contains('50cl Sachet x10'));
      expect(text, contains('NGN4,000'));
      expect(text, contains('Balance'));
      expect(text, contains('NGN3,000'));
      expect(text, contains('Thank you'));
      expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x30]);
    }
  });
}
