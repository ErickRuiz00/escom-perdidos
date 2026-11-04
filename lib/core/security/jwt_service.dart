import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Emite y valida tokens JWT (HS256) para mantener la sesión activa.
///
/// La llave de firma se genera aleatoriamente en cada instalación y vive en el
/// almacenamiento seguro del sistema (Keystore / Keychain), nunca en el código.
class JwtService {
  const JwtService();

  static const sessionDuration = Duration(days: 7);

  String issue({
    required String userId,
    required String email,
    required String secret,
    DateTime? now,
    Duration ttl = sessionDuration,
  }) {
    final issuedAt = now ?? DateTime.now();
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'sub': userId,
      'email': email,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': issuedAt.add(ttl).millisecondsSinceEpoch ~/ 1000,
    };
    final unsigned = '${_encode(header)}.${_encode(payload)}';
    return '$unsigned.${_sign(unsigned, secret)}';
  }

  /// Devuelve el payload si la firma es válida y el token no ha expirado.
  Map<String, dynamic>? verify(String token, String secret, {DateTime? now}) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final expected = _sign('${parts[0]}.${parts[1]}', secret);
    if (expected != parts[2]) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      final current = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      if (exp == null || current >= exp) return null;
      return payload;
    } on FormatException {
      return null;
    }
  }

  String _encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  String _sign(String data, String secret) {
    final digest = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(data));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
