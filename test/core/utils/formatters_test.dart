import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/formatters.dart';

void main() {
  group('toE164Nigeria', () {
    test('converts a local 11-digit number', () {
      expect(toE164Nigeria('08031234567'), '+2348031234567');
    });

    test('strips non-digit characters before converting', () {
      expect(toE164Nigeria('0803 123 4567'), '+2348031234567');
    });

    test('leaves a number with no leading zero alone', () {
      expect(toE164Nigeria('8031234567'), '+2348031234567');
    });
  });

  group('formatNaira', () {
    test('formats whole numbers with thousands separators and symbol', () {
      expect(formatNaira(1240500), '₦1,240,500');
    });

    test('formats zero', () {
      expect(formatNaira(0), '₦0');
    });

    test('rounds to whole naira (no decimal digits)', () {
      expect(formatNaira(999.6), '₦1,000');
    });
  });

  group('toTitleCase', () {
    test('capitalizes a single lowercase word', () {
      expect(toTitleCase('kaduna'), 'Kaduna');
    });

    test('capitalizes each word in a multi-word area', () {
      expect(toTitleCase('wuse 2'), 'Wuse 2');
    });

    test('lowercases the rest of an all-caps word', () {
      expect(toTitleCase('KADUNA'), 'Kaduna');
    });

    test('leaves an empty string alone', () {
      expect(toTitleCase(''), '');
    });
  });

  group('ThousandsInputFormatter', () {
    final formatter = ThousandsInputFormatter();

    TextEditingValue format(String text) {
      return formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    test('groups digits as the user types', () {
      expect(format('1240500').text, '1,240,500');
    });

    test('strips non-digit characters first', () {
      expect(format('1,240,500').text, '1,240,500');
    });

    test('returns empty text for empty input', () {
      expect(format('').text, '');
    });

    test('places the cursor at the end of the formatted text', () {
      final result = format('1240500');
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
