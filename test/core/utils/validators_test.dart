import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/validators.dart';

void main() {
  group('Validators.phoneOrEmail', () {
    test('accepts an 11-digit phone number', () {
      expect(Validators.phoneOrEmail('08031234567'), isNull);
    });

    test('accepts an email address', () {
      expect(Validators.phoneOrEmail('owner@example.com'), isNull);
    });

    test('rejects a short phone number and a malformed email', () {
      expect(Validators.phoneOrEmail('0803123'), isNotNull);
      expect(Validators.phoneOrEmail('owner@'), isNotNull);
    });
  });

  group('Validators.pin', () {
    test('accepts exactly six digits only', () {
      expect(Validators.pin('123456'), isNull);
      expect(Validators.pin('12345'), isNotNull);
      expect(Validators.pin('12345a'), isNotNull);
      expect(Validators.pin('1234567'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('needs at least the minimum length', () {
      expect(Validators.password('a' * Validators.passwordMinLength), isNull);
      expect(
        Validators.password('a' * (Validators.passwordMinLength - 1)),
        isNotNull,
      );
    });
  });

  group('Validators.required', () {
    test('rejects blank text', () {
      expect(Validators.required('   ', 'Enter it'), 'Enter it');
      expect(Validators.required('x', 'Enter it'), isNull);
    });
  });

  group('Validators.accountNumber', () {
    test('accepts a 10-digit NUBAN', () {
      expect(Validators.accountNumber('0123456789'), isNull);
    });

    test('rejects the wrong length or non-digits', () {
      expect(Validators.accountNumber('012345678'), isNotNull);
      expect(Validators.accountNumber('01234567890'), isNotNull);
      expect(Validators.accountNumber('01234-6789'), isNotNull);
      expect(Validators.accountNumber(null), isNotNull);
    });
  });
}
