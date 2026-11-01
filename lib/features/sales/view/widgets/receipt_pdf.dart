import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/pdf_formatters.dart';
import '../../data/models/sale.dart';

/// Builds a one-page receipt PDF for [sale] — same content and order as
/// [ReceiptScreen], just laid out for print/share instead of the
/// screen. Sized to a narrow page so it also prints sensibly on a
/// thermal/till-roll printer, not just A4.
Future<pw.Document> buildReceiptPdf(
  Sale sale, {
  required String businessName,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(
        227, // ~80mm thermal roll width, in points
        double.infinity,
        marginAll: 16,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              DateFormat.yMMMd().add_jm().format(sale.dateTime),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              sale.customerName ?? 'Walk-in customer',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),
            for (final line in sale.lines) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${line.product.label} x ${line.quantity}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Text(
                    pdfNaira(line.lineTotal),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),
            _pdfRow('Total', pdfNaira(sale.total), bold: true),
            _pdfRow('Paid', pdfNaira(sale.amountPaid)),
            _pdfRow(
              'Balance',
              pdfNaira(sale.balance),
              // Mirrors ReceiptScreen's own fix: a zero balance (paid)
              // stays neutral, and a part-paid balance reads amber, not
              // red — matching SalePaymentStatusBadge's status colors
              // rather than a flat "any balance = red" sign check.
              color: sale.balance <= 0
                  ? null
                  : sale.paymentStatus == SalePaymentStatus.partPaid
                  ? PdfColors.amber700
                  : PdfColors.red700,
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Text(
              'Served by ${sale.recordedBy}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _pdfRow(
  String label,
  String value, {
  bool bold = false,
  PdfColor? color,
}) {
  final style = pw.TextStyle(
    fontSize: bold ? 12 : 10,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: style.copyWith(color: color ?? PdfColors.grey700),
        ),
        pw.Text(value, style: style),
      ],
    ),
  );
}
