import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SDK session JSON stored through Android Keystore / iOS Keychain.
/// Each project has its own key; legacy local JWTs use a different key.
class SupabaseAuthStorage extends LocalStorage {
  SupabaseAuthStorage({
    required String projectHost,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage,
       _key = 'supabase_session_$projectHost';

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

/// PKCE binds an email callback to the device that requested the email.
class SupabasePkceStorage extends GotrueAsyncStorage {
  SupabasePkceStorage({
    required String projectHost,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage,
       _prefix = 'supabase_pkce_$projectHost';

  final FlutterSecureStorage _storage;
  final String _prefix;

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '${_prefix}_$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '${_prefix}_$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '${_prefix}_$key');
}
