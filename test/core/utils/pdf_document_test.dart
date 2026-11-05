import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/pdf_document.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDFs use a font that has the naira sign', () async {
    final doc = await newPdfDocument();
    final theme = doc.theme!;
    for (final font in [theme.defaultTextStyle.font, theme.header0.font]) {
      final ttf = font! as pw.TtfFont;
      expect(
        TtfParser(ttf.data).charToGlyphIndexMap.containsKey(0x20A6),
        isTrue,
      );
    }
    doc.addPage(pw.Page(build: (_) => pw.Text('₦1,240,500')));
    expect(await doc.save(), isNotEmpty);
  });
}
