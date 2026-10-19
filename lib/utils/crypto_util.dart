import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hashing password: PBKDF2-HMAC-SHA256 + salt acak per user.
/// Password asli TIDAK PERNAH disimpan.
class CryptoUtil {
  static const int _iterations = 10000;

  static String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    return base64UrlEncode(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static String generateToken([int length = 32]) => generateSalt(length);

  static String hashPassword(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = base64Url.decode(salt);

    // PBKDF2, 1 blok (32 byte) cukup untuk SHA-256.
    var u = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64UrlEncode(result);
  }

  /// Perbandingan waktu-konstan agar tahan timing attack.
  static bool verify(String password, String salt, String expectedHash) {
    final actual = hashPassword(password, salt);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
