import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/pdf_formatters.dart';
import '../../../sales/data/models/sale.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

/// Builds a one-page report PDF for [summary] — same sections, same
/// order, same comparison wording as the on-screen cards
/// ([ReportComparisonLine] via [formatReportComparison]), laid out as a
/// plain A4 document rather than six separate cards.
Future<pw.Document> buildReportPdf(
  ReportSummary summary, {
  required String businessName,
}) async {
  final doc = pw.Document();
  final comparisonLabel = summary.period.comparisonLabel;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '${summary.period.label} report',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generated ${DateFormat.yMMMd().add_jm().format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),
            _section(
              'Profit',
              [
                _row('Revenue', pdfNaira(summary.profit.revenue)),
                _row('Expenses', pdfNaira(summary.profit.expenses)),
                _row('Profit', pdfNaira(summary.profit.profit), bold: true),
              ],
              formatReportComparison(
                current: summary.profit.profit,
                previous: summary.profit.previousProfit,
                comparisonLabel: comparisonLabel,
              ),
            ),
            _section(
              'Sales',
              [
                _row('Bags sold', '${summary.sales.bagsSold}'),
                _row('Revenue', pdfNaira(summary.sales.revenue)),
                for (final entry in summary.sales.revenueByMethod.entries)
                  _row('Revenue — ${entry.key.label}', pdfNaira(entry.value)),
              ],
              formatReportComparison(
                current: summary.sales.revenue,
                previous: summary.sales.previousRevenue,
                comparisonLabel: comparisonLabel,
              ),
            ),
            _section(
              'Production',
              [
                _row('Bags produced', '${summary.production.bagsProduced}'),
                _row('Wastage', '${summary.production.wastage} bags'),
              ],
              formatReportComparison(
                current: summary.production.bagsProduced,
                previous: summary.production.previousBagsProduced,
                comparisonLabel: comparisonLabel,
                formatValue: (value) =>
                    '${value.round()} ${value.round() == 1 ? 'bag' : 'bags'}',
              ),
            ),
            _section(
              'Cash',
              [
                _row('Cash in', pdfNaira(summary.cash.cashIn)),
                _row('Cash out', pdfNaira(summary.cash.cashOut)),
                _row(
                  'Closing cash in hand',
                  pdfNaira(summary.cash.closingCash),
                  bold: true,
                ),
              ],
              formatReportComparison(
                current: summary.cash.closingCash,
                previous: summary.cash.previousClosingCash,
                comparisonLabel: comparisonLabel,
              ),
            ),
            _section(
              'Money outside',
              [
                _row('Opening', pdfNaira(summary.moneyOutside.opening)),
                _row(
                  'Closing',
                  pdfNaira(summary.moneyOutside.closing),
                  bold: true,
                ),
              ],
              formatReportComparison(
                current: summary.moneyOutside.closing,
                previous: summary.moneyOutside.previousClosing,
                comparisonLabel: comparisonLabel,
                higherIsBetter: false,
              ),
            ),
            _section(
              'Stock',
              summary.stock.lowItems.isEmpty
                  ? [_row('Status', 'No finished goods running low.')]
                  : [
                      for (final item in summary.stock.lowItems)
                        _row(
                          item.name,
                          '${item.quantityRemaining} ${item.unit} left',
                        ),
                    ],
              formatReportComparison(
                current: summary.stock.lowItems.length,
                previous: summary.stock.previousLowItemCount,
                comparisonLabel: comparisonLabel,
                higherIsBetter: false,
                formatValue: (value) =>
                    '${value.round()} ${value.round() == 1 ? 'item' : 'items'}',
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _section(
  String title,
  List<pw.Widget> rows,
  ReportComparisonText comparison,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        ...rows,
        pw.SizedBox(height: 4),
        pw.Text(
          comparison.text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: switch (comparison.isGood) {
              null => PdfColors.grey700,
              true => PdfColors.green700,
              false => PdfColors.red700,
            },
          ),
        ),
      ],
    ),
  );
}

pw.Widget _row(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(
    fontSize: bold ? 12 : 10,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style.copyWith(color: PdfColors.grey700)),
        pw.Text(value, style: style),
      ],
    ),
  );
}
