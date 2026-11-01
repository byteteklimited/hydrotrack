import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../../core/utils/formatters.dart';
import '../../../organizations/data/models/business_header.dart';
import '../../../sales/data/models/sale.dart';
import '../../data/models/report_summary.dart';
import 'report_comparison_line.dart';

/// One field, quoted per RFC 4180 whenever it contains a comma, quote,
/// or newline — [formatNaira]'s own thousands separator means almost
/// every amount needs it.
String _field(String value) {
  if (value.contains(RegExp(r'[,"\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _row(List<String> fields) => fields.map(_field).join(',');

/// Builds a CSV export of [summary] — same sections, same order, same
/// comparison wording as the on-screen cards and [buildReportPdf],
/// as a plain "label,value" sheet Excel/Sheets/Numbers open directly.
/// A leading UTF-8 BOM keeps the ₦ sign readable in Excel, which
/// otherwise guesses the wrong encoding for a plain UTF-8 file.
Uint8List buildReportCsv(
  ReportSummary summary, {
  required BusinessHeader header,
}) {
  final comparisonLabel = summary.period.comparisonLabel;
  final lines = <String>[
    _row(['${header.name} — Report']),
    for (final line in header.lines) _row([line]),
    _row(['Period', summary.period.label]),
    _row(['Generated', DateFormat.yMMMd().add_jm().format(DateTime.now())]),
    '',
    _row(['Profit']),
    _row(['Revenue', formatNaira(summary.profit.revenue)]),
    _row(['Expenses', formatNaira(summary.profit.expenses)]),
    _row(['Profit', formatNaira(summary.profit.profit)]),
    _row([
      'Change',
      formatReportComparison(
        current: summary.profit.profit,
        previous: summary.profit.previousProfit,
        comparisonLabel: comparisonLabel,
      ).text,
    ]),
    '',
    _row(['Sales']),
    _row(['Bags sold', '${summary.sales.bagsSold}']),
    _row(['Revenue', formatNaira(summary.sales.revenue)]),
    for (final entry in summary.sales.revenueByMethod.entries)
      _row(['Revenue — ${entry.key.label}', formatNaira(entry.value)]),
    _row([
      'Change',
      formatReportComparison(
        current: summary.sales.revenue,
        previous: summary.sales.previousRevenue,
        comparisonLabel: comparisonLabel,
      ).text,
    ]),
    '',
    _row(['Production']),
    _row(['Bags produced', '${summary.production.bagsProduced}']),
    _row(['Wastage', '${summary.production.wastage} bags']),
    _row([
      'Change',
      formatReportComparison(
        current: summary.production.bagsProduced,
        previous: summary.production.previousBagsProduced,
        comparisonLabel: comparisonLabel,
        formatValue: (value) =>
            '${value.round()} ${value.round() == 1 ? 'bag' : 'bags'}',
      ).text,
    ]),
    '',
    _row(['Cash']),
    _row(['Cash in', formatNaira(summary.cash.cashIn)]),
    _row(['Cash out', formatNaira(summary.cash.cashOut)]),
    _row(['Closing cash in hand', formatNaira(summary.cash.closingCash)]),
    _row([
      'Change',
      formatReportComparison(
        current: summary.cash.closingCash,
        previous: summary.cash.previousClosingCash,
        comparisonLabel: comparisonLabel,
      ).text,
    ]),
    '',
    _row(['Money outside']),
    _row(['Opening', formatNaira(summary.moneyOutside.opening)]),
    _row(['Closing', formatNaira(summary.moneyOutside.closing)]),
    _row([
      'Change',
      formatReportComparison(
        current: summary.moneyOutside.closing,
        previous: summary.moneyOutside.previousClosing,
        comparisonLabel: comparisonLabel,
        higherIsBetter: false,
      ).text,
    ]),
    '',
    _row(['Stock']),
    if (summary.stock.lowItems.isEmpty)
      _row(['Status', 'No finished goods running low.'])
    else
      for (final item in summary.stock.lowItems)
        _row([item.name, '${item.quantityRemaining} ${item.unit} left']),
    _row([
      'Change',
      formatReportComparison(
        current: summary.stock.lowItems.length,
        previous: summary.stock.previousLowItemCount,
        comparisonLabel: comparisonLabel,
        higherIsBetter: false,
        formatValue: (value) =>
            '${value.round()} ${value.round() == 1 ? 'item' : 'items'}',
      ).text,
    ]),
  ];

  return Uint8List.fromList(utf8.encode('﻿${lines.join('\r\n')}'));
}
