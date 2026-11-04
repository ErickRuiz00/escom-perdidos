import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de contraseñas con PBKDF2-HMAC-SHA256 y sal aleatoria por usuario.
///
/// Nunca se guarda la contraseña en claro (RNF2 - Seguridad).
class PasswordHasher {
  const PasswordHasher({this.iterations = 10000});

  final int iterations;
  static const _keyLength = 32;

  String generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String hash(String password, String salt) {
    final derived = _pbkdf2(utf8.encode(password), utf8.encode(salt));
    return base64UrlEncode(derived);
  }

  bool verify(String password, String salt, String expectedHash) {
    return _constantTimeEquals(hash(password, salt), expectedHash);
  }

  // PBKDF2 con un único bloque (la salida de SHA-256 ya mide 32 bytes).
  Uint8List _pbkdf2(List<int> password, List<int> salt) {
    final hmac = Hmac(sha256, password);
    final block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
    var u = hmac.convert(block).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
