import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../../organizations/data/models/business_header.dart';
import '../../sales/data/models/sale.dart';
import 'receipt_printer_settings.dart';

/// A sale's receipt as ESC/POS printer commands — same content as the
/// on-screen and PDF receipt. Amounts use "NGN": most receipt printers'
/// built-in fonts have no ₦ sign.
Future<List<int>> buildEscPosReceipt(
  Sale sale, {
  required BusinessHeader header,
  required PaperWidth paper,
  CapabilityProfile? profile,
}) async {
  final generator = Generator(
    paper == PaperWidth.mm80 ? PaperSize.mm80 : PaperSize.mm58,
    profile ?? await CapabilityProfile.load(),
  );
  final money = NumberFormat.decimalPattern('en_NG');
  String naira(num amount) => 'NGN${money.format(amount)}';
  const centered = PosStyles(align: PosAlign.center);

  List<int> pair(String left, String right, {bool bold = false}) =>
      generator.row([
        PosColumn(
          text: left,
          width: 7,
          styles: PosStyles(bold: bold),
        ),
        PosColumn(
          text: right,
          width: 5,
          styles: PosStyles(align: PosAlign.right, bold: bold),
        ),
      ]);

  return [
    ...generator.reset(),
    ...generator.text(
      header.name,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    ),
    for (final line in header.lines) ...generator.text(line, styles: centered),
    ...generator.hr(),
    ...generator.text(DateFormat('d MMM yyyy, h:mm a').format(sale.dateTime)),
    ...generator.text(sale.customerName ?? 'Walk-in customer'),
    ...generator.hr(),
    for (final line in sale.lines)
      ...pair('${line.product.label} x${line.quantity}', naira(line.lineTotal)),
    ...generator.hr(),
    ...pair('Total', naira(sale.total), bold: true),
    ...pair('Paid', naira(sale.amountPaid)),
    if (sale.balance > 0) ...pair('Balance', naira(sale.balance), bold: true),
    if (sale.isVoided) ...generator.text('VOIDED', styles: centered),
    if (sale.batchNumbers.isNotEmpty)
      ...generator.text('Batch ${sale.batchNumbers.join(', ')}'),
    ...generator.feed(1),
    ...generator.text('Thank you', styles: centered),
    ...generator.feed(2),
    ...generator.cut(),
  ];
}
