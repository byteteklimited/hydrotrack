import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/organizations/data/models/business_header.dart';

/// Logo, business name and profile lines at the top of a receipt or
/// report PDF. [nameSize] scales the name for the page (narrow receipt
/// roll vs A4 report).
pw.Widget pdfBusinessHeader(BusinessHeader header, {required double nameSize}) {
  final logo = header.logo;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null) ...[
        pw.Image(pw.MemoryImage(logo), height: nameSize * 2.5),
        pw.SizedBox(height: 4),
      ],
      pw.Text(
        header.name,
        style: pw.TextStyle(fontSize: nameSize, fontWeight: pw.FontWeight.bold),
      ),
      for (final line in header.lines)
        pw.Text(
          line,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
    ],
  );
}
