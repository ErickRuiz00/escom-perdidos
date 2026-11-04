import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Envoltorio sobre el almacenamiento seguro del sistema operativo
/// (Android Keystore / iOS Keychain) para el token de sesión y la llave de firma.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'session_token';
  static const _secretKey = 'jwt_signing_secret';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  /// Llave HMAC aleatoria de 256 bits, creada la primera vez que se necesita.
  Future<String> signingSecret() async {
    final existing = await _storage.read(key: _secretKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final secret = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    await _storage.write(key: _secretKey, value: secret);
    return secret;
  }
}
