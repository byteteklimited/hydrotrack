import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_business_header.dart';
import '../../../../core/utils/pdf_document.dart';
import '../../../organizations/data/models/business_header.dart';
import '../../data/models/payroll.dart';
import '../../data/models/worker.dart';

/// How a line was worked out, row by row (label, amount or count) — the
/// same rows on screen and on the payslip.
List<(String, String)> payslipRows(PayrollLine line) => [
  switch (line.payType) {
    PayType.monthly => ('Monthly salary', formatNaira(line.gross)),
    PayType.daily => (
      '${formatPlain(line.daysPresent)} days × ${formatNaira(line.rate)}',
      formatNaira(line.gross),
    ),
    PayType.perBag => (
      '${line.bags} bags × ${formatNaira(line.rate)}',
      formatNaira(line.gross),
    ),
  },
  if (line.absenceDeduction > 0)
    (
      'Absent ${formatPlain(line.daysAbsent)} days',
      '- ${formatNaira(line.absenceDeduction)}',
    ),
  if (line.advances > 0) ('Advances', '- ${formatNaira(line.advances)}'),
  if (line.adjustment != 0)
    (
      line.adjustmentNote ?? 'Adjustment',
      '${line.adjustment < 0 ? '- ' : '+ '}${formatNaira(line.adjustment.abs())}',
    ),
];

/// One person's payslip for a paid payroll.
Future<pw.Document> buildPayslipPdf(
  PayrollLine line,
  Payroll payroll, {
  required BusinessHeader header,
}) async {
  final doc = await newPdfDocument();
  final month = DateFormat('MMMM yyyy').format(payroll.month);
  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label),
        pw.Text(
          value,
          style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        ),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pdfBusinessHeader(header, nameSize: 16),
          pw.SizedBox(height: 12),
          pw.Text(
            'Payslip · $month',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(line.workerName),
          pw.SizedBox(height: 8),
          pw.Divider(),
          for (final (label, value) in payslipRows(line)) row(label, value),
          pw.Divider(),
          row('Paid', formatNaira(line.net), bold: true),
          if (payroll.paidAt != null)
            pw.Text(
              'Paid on ${DateFormat('d MMM yyyy').format(payroll.paidAt!)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
        ],
      ),
    ),
  );
  return doc;
}
