import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/offline/data/models/offline_credential.dart';
import 'package:hydrotrack/features/offline/data/models/offline_member.dart';

void main() {
  group('OfflineCredential', () {
    test('matches the PIN it was made from and nothing else', () {
      final credential = OfflineCredential.create('482913', iterations: 1000);
      expect(credential.matches('482913'), isTrue);
      expect(credential.matches('482914'), isFalse);
      expect(credential.matches(''), isFalse);
    });

    test('never contains the PIN, and is salted', () {
      final a = OfflineCredential.create('482913', iterations: 1000);
      final b = OfflineCredential.create('482913', iterations: 1000);
      expect(jsonEncode(a.toJson()), isNot(contains('482913')));
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('PBKDF2-HMAC-SHA256 matches the RFC 7914 test vector', () {
      final key = OfflineCredential.pbkdf2(
        utf8.encode('passwd'),
        utf8.encode('salt'),
        1,
      );
      expect(
        key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });
  });

  group('OfflineMember.normalizeIdentifier', () {
    test('treats 080…, +234… and 234… as the same phone number', () {
      expect(OfflineMember.normalizeIdentifier('08031234567'), '2348031234567');
      expect(
        OfflineMember.normalizeIdentifier('+234 803 123 4567'),
        '2348031234567',
      );
      expect(
        OfflineMember.normalizeIdentifier('2348031234567'),
        '2348031234567',
      );
    });

    test('lower-cases emails', () {
      expect(
        OfflineMember.normalizeIdentifier(' Owner@Sunny.NG '),
        'owner@sunny.ng',
      );
    });
  });
}
