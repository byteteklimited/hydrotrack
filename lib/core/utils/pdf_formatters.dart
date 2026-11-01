import 'package:intl/intl.dart';

/// Base14 PDF fonts (Helvetica etc.) only cover Latin-1 — the ₦ glyph
/// (U+20A6) isn't in it, and rendering it would need a bundled Unicode
/// font or a network font fetch at print time, which a core export
/// shouldn't depend on. "N" is also what a lot of real thermal receipt
/// printers already fall back to for the exact same reason. Shared by
/// every PDF this app generates so they can't drift into two different
/// conventions.
String pdfNaira(num amount) {
  return 'N${NumberFormat.decimalPattern('en_NG').format(amount)}';
}
