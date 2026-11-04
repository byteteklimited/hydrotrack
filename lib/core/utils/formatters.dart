import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Converts a local Nigerian phone number (e.g. `08031234567`) to E.164
/// (e.g. `+2348031234567`) for Supabase phone auth. The UI always shows
/// and stores the local format — this conversion is internal only.
String toE164Nigeria(String localPhone) {
  final digits = localPhone.replaceAll(RegExp(r'[^\d]'), '');
  final withoutLeadingZero = digits.startsWith('0')
      ? digits.substring(1)
      : digits;
  return '+234$withoutLeadingZero';
}

/// Capitalizes each word, e.g. `kaduna` → `Kaduna`, `wuse 2` → `Wuse 2`.
/// Display-only — never mutates stored data, so existing lowercase
/// records read correctly without needing a migration.
String toTitleCase(String text) {
  if (text.trim().isEmpty) return text;
  return text
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Formats a raw number as a naira amount, e.g. `1240500` → `₦1,240,500`.
String formatNaira(num amount) {
  return NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  ).format(amount);
}

/// Same as [formatNaira], but with kobo shown — for the rarer spot where
/// the fractional naira actually matters (e.g. a per-unit price), rather
/// than every whole-naira total in the app switching to this by default.
String formatNairaWithKobo(num amount) {
  return NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  ).format(amount);
}

/// Formats a quantity with its unit, e.g. `3000, 'bags'` → `3,000 bags`.
String formatQuantity(num amount, String unit) {
  return '${NumberFormat.decimalPattern('en_NG').format(amount)} $unit';
}

/// Live thousands-grouping formatter — reformats digits as the user types
/// so a ₦ amount field reads `1,240,500` instead of `1240500`.
class ThousandsInputFormatter extends TextInputFormatter {
  static final NumberFormat _grouping = NumberFormat.decimalPattern('en_NG');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final formatted = _grouping.format(int.parse(digitsOnly));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Strips the thousands-grouping `AppTextField.naira` adds live, so the
/// typed amount can be read back as a number.
num parseNairaText(String text) => num.tryParse(text.replaceAll(',', '')) ?? 0;

/// A number without trailing zeros, as Postgres `trim_scale` prints it:
/// 9.10 → "9.1", 500.0 → "500".
String formatPlain(num value) {
  final text = value.toString();
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A name made safe for a file name: "Sunny Water Ltd." → "sunny-water-ltd".
String fileSlug(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'records' : slug;
}
