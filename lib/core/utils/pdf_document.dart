import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Roboto, bundled with the app: the fonts built into PDF readers only
/// cover Latin-1 and have no ₦, so every PDF the app makes uses these.
const _regularFont = 'assets/fonts/Roboto-Regular.ttf';
const _boldFont = 'assets/fonts/Roboto-Bold.ttf';

pw.ThemeData? _theme;

/// A new PDF that can show ₦ (and −, —, ·). Fonts are loaded once.
Future<pw.Document> newPdfDocument() async {
  _theme ??= pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load(_regularFont)),
    bold: pw.Font.ttf(await rootBundle.load(_boldFont)),
  );
  return pw.Document(theme: _theme);
}
