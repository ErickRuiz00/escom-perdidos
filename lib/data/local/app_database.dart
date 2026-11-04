import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local (RF3 - Persistencia offline).
///
/// Toda la información se guarda en el dispositivo, por lo que la app se puede
/// consultar sin conexión a internet.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactory,
        _path = path;

  static const _name = 'escom_perdidos.db';
  static const _version = 1;

  final DatabaseFactory _factory;
  final String? _path;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = _path ?? p.join(await _factory.getDatabasesPath(), _name);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        provider TEXT NOT NULL,
        password_hash TEXT,
        password_salt TEXT,
        boleta TEXT,
        phone TEXT,
        avatar_path TEXT,
        avatar_url TEXT,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        dark_mode INTEGER NOT NULL DEFAULT 0,
        reset_code_hash TEXT,
        reset_code_expires INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        event_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        photo_path TEXT,
        latitude REAL,
        longitude REAL,
        contact TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_reports_user ON reports(user_id)');
    batch.execute('CREATE INDEX idx_reports_created ON reports(created_at)');
    batch.execute('''
      CREATE TABLE weather_cache (
        id INTEGER PRIMARY KEY,
        temperature REAL NOT NULL,
        weather_code INTEGER NOT NULL,
        precipitation_probability INTEGER NOT NULL,
        fetched_at INTEGER NOT NULL
      )
    ''');
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
