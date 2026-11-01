import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A one-way check of someone's PIN/password for signing in without
/// internet: PBKDF2-HMAC-SHA256 with a random salt. The PIN/password
/// itself is never stored or sent; only this. Created after each online
/// sign-in and kept on the server (`offline_credentials`), from where set
/// up devices download it.
class OfflineCredential {
  const OfflineCredential({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Hex, 16 bytes.
  final String salt;

  /// Hex, 32 bytes.
  final String hash;
  final int iterations;

  /// Slows down guessing a stolen check; also fast enough to sign in on
  /// a basic phone or in a browser.
  static const defaultIterations = 60000;
  static const _saltBytes = 16;

  static OfflineCredential create(
    String secret, {
    int iterations = defaultIterations,
    Random? random,
  }) {
    final generator = random ?? Random.secure();
    final salt = List<int>.generate(_saltBytes, (_) => generator.nextInt(256));
    return OfflineCredential(
      salt: _hex(salt),
      hash: _hex(pbkdf2(utf8.encode(secret), salt, iterations)),
      iterations: iterations,
    );
  }

  bool matches(String secret) {
    final computed = _hex(
      pbkdf2(utf8.encode(secret), _unhex(salt), iterations),
    );
    // Compare every character so timing doesn't hint how much matched.
    if (computed.length != hash.length) return false;
    var difference = 0;
    for (var i = 0; i < hash.length; i++) {
      difference |= computed.codeUnitAt(i) ^ hash.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  static List<int> pbkdf2(List<int> secret, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, secret);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.of(block);
    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _unhex(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  factory OfflineCredential.fromJson(Map<String, dynamic> json) {
    return OfflineCredential(
      salt: json['salt'] as String,
      hash: json['hash'] as String,
      iterations: json['iterations'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };
}
