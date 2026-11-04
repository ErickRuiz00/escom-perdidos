import 'dart:isolate';
import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/security/jwt_service.dart';
import '../../core/security/password_hasher.dart';
import '../local/app_database.dart';
import '../local/secure_store.dart';
import '../models/user.dart';
import '../services/google_auth_service.dart';

/// Registro, ingreso, sesión y recuperación de contraseña (RF1).
class AuthRepository {
  AuthRepository({
    required AppDatabase database,
    required SecureStore secureStore,
    GoogleAuthService? google,
    PasswordHasher hasher = const PasswordHasher(),
    JwtService jwt = const JwtService(),
  })  : _database = database,
        _secure = secureStore,
        _google = google ?? GoogleAuthService(),
        _hasher = hasher,
        _jwt = jwt;

  final AppDatabase _database;
  final SecureStore _secure;
  final GoogleAuthService _google;
  final PasswordHasher _hasher;
  final JwtService _jwt;

  static const resetCodeValidity = Duration(minutes: 15);

  bool get googleAvailable => _google.isAvailable;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? boleta,
  }) async {
    final db = await _database.database;
    final normalized = email.trim().toLowerCase();
    if (await _findRow(db, normalized) != null) {
      throw const AuthException('Ya existe una cuenta con ese correo.');
    }
    final salt = _hasher.generateSalt();
    final user = AppUser(
      id: const Uuid().v4(),
      name: name.trim(),
      email: normalized,
      provider: 'local',
      createdAt: DateTime.now(),
      boleta: _emptyToNull(boleta?.toUpperCase()),
    );
    final hash = await _hash(password, salt);
    await _guard(() => db.insert('users', {
          ...user.toMap(),
          'password_salt': salt,
          'password_hash': hash,
        }));
    await _startSession(user);
    return user;
  }

  Future<AppUser> login(String email, String password) async {
    final db = await _database.database;
    final row = await _findRow(db, email.trim().toLowerCase());
    // Mismo mensaje para correo inexistente y contraseña incorrecta.
    const invalid = AuthException('Correo o contraseña incorrectos.');
    if (row == null) throw invalid;
    if (row['provider'] != 'local') {
      throw const AuthException('Esta cuenta usa otro método de ingreso (Google).');
    }
    final ok = await _verify(
      password,
      row['password_salt'] as String,
      row['password_hash'] as String,
    );
    if (!ok) throw invalid;
    final user = AppUser.fromMap(row);
    await _startSession(user);
    return user;
  }

  /// Devuelve `null` si el usuario cancela el flujo de Google.
  Future<AppUser?> signInWithGoogle() async {
    final profile = await _google.signIn();
    if (profile == null) return null;
    final db = await _database.database;
    final email = profile.email.toLowerCase();
    final row = await _findRow(db, email);
    AppUser user;
    if (row == null) {
      user = AppUser(
        id: const Uuid().v4(),
        name: profile.name ?? email.split('@').first,
        email: email,
        provider: 'google',
        createdAt: DateTime.now(),
        avatarUrl: profile.photoUrl,
      );
      await _guard(() => db.insert('users', user.toMap()));
    } else {
      user = AppUser.fromMap(row);
    }
    await _startSession(user);
    return user;
  }

  /// Restaura la sesión si existe un token válido y no expirado.
  Future<AppUser?> restoreSession() async {
    final token = await _secure.readToken();
    if (token == null) return null;
    final payload = _jwt.verify(token, await _secure.signingSecret());
    if (payload == null) {
      await _secure.deleteToken();
      return null;
    }
    final user = await findById(payload['sub'] as String);
    if (user == null) await _secure.deleteToken();
    return user;
  }

  Future<void> logout() async {
    await _secure.deleteToken();
    await _google.signOut();
  }

  Future<AppUser?> findById(String id) async {
    final db = await _database.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// Genera un código de 6 dígitos para restablecer la contraseña.
  ///
  /// Sin servidor de correo, la vista lo entrega al usuario mediante una
  /// notificación local. En la BD solo se guarda su hash y su vigencia.
  Future<String> requestPasswordReset(String email) async {
    final db = await _database.database;
    final row = await _findRow(db, email.trim().toLowerCase());
    if (row == null || row['provider'] != 'local') {
      throw const AuthException('No encontramos una cuenta con ese correo.');
    }
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    await db.update(
      'users',
      {
        'reset_code_hash': await _hash(code, row['password_salt'] as String),
        'reset_code_expires':
            DateTime.now().add(resetCodeValidity).millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    return code;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final db = await _database.database;
    final row = await _findRow(db, email.trim().toLowerCase());
    final storedHash = row?['reset_code_hash'] as String?;
    final expires = row?['reset_code_expires'] as int?;
    if (row == null || storedHash == null || expires == null) {
      throw const AuthException('Solicita un nuevo código.');
    }
    if (DateTime.now().millisecondsSinceEpoch > expires) {
      throw const AuthException('El código expiró. Solicita uno nuevo.');
    }
    if (!await _verify(code.trim(), row['password_salt'] as String, storedHash)) {
      throw const AuthException('El código no es correcto.');
    }
    await _setPassword(db, row['id'] as String, newPassword);
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _database.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) throw const AuthException('Usuario no encontrado.');
    final row = rows.first;
    final ok = await _verify(
      currentPassword,
      row['password_salt'] as String,
      row['password_hash'] as String,
    );
    if (!ok) throw const AuthException('La contraseña actual no es correcta.');
    await _setPassword(db, userId, newPassword);
  }

  Future<AppUser> updateProfile(AppUser user) async {
    final db = await _database.database;
    await _guard(() => db.update(
          'users',
          {
            'name': user.name.trim(),
            'boleta': _emptyToNull(user.boleta?.toUpperCase()),
            'phone': _emptyToNull(user.phone),
            'avatar_path': user.avatarPath,
            'notifications_enabled': user.notificationsEnabled ? 1 : 0,
            'dark_mode': user.darkMode ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [user.id],
        ));
    return (await findById(user.id))!;
  }

  Future<void> _setPassword(Database db, String userId, String password) async {
    final salt = _hasher.generateSalt();
    await db.update(
      'users',
      {
        'password_salt': salt,
        'password_hash': await _hash(password, salt),
        'reset_code_hash': null,
        'reset_code_expires': null,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> _startSession(AppUser user) async {
    final token = _jwt.issue(
      userId: user.id,
      email: user.email,
      secret: await _secure.signingSecret(),
    );
    await _secure.writeToken(token);
  }

  Future<Map<String, Object?>?> _findRow(Database db, String email) async {
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // PBKDF2 es costoso a propósito: se calcula en otro isolate para no
  // bloquear el hilo de la UI (RNF1 - 60 fps).
  Future<String> _hash(String value, String salt) {
    final hasher = _hasher;
    return Isolate.run(() => hasher.hash(value, salt));
  }

  Future<bool> _verify(String value, String salt, String expected) {
    final hasher = _hasher;
    return Isolate.run(() => hasher.verify(value, salt, expected));
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw StorageException('No se pudo guardar la información.', cause: e);
    }
  }

  String? _emptyToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
