import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/local/secure_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base de datos SQLite en memoria para pruebas (no toca el dispositivo).
AppDatabase memoryDatabase() {
  sqfliteFfiInit();
  return AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
}

/// Sustituto del almacenamiento seguro que guarda en memoria.
class FakeSecureStore implements SecureStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<void> deleteToken() async => token = null;

  @override
  Future<String> signingSecret() async => 'test-secret-de-pruebas';
}
