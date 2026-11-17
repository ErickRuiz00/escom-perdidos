import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/errors/app_exception.dart';
import '../../core/config/env.dart';
import '../local/app_database.dart';
import '../local/secure_store.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/auth_link_service.dart';

/// Supabase owns credentials and sessions. SQLite is only a compatibility
/// cache for the existing report foreign keys and device-local avatars.
class AuthRepository {
  AuthRepository({
    required AppDatabase database,
    required SecureStore secureStore,
    required SupabaseService supabase,
    this.emailOtpEnabled = Env.supabaseEmailOtpEnabled,
  }) : _database = database,
       _secure = secureStore,
       _supabase = supabase;

  final AppDatabase _database;
  final SecureStore _secure;
  final SupabaseService _supabase;
  final bool emailOtpEnabled;
  sb.SupabaseClient? _recoveryClient;

  bool get googleAvailable => false;
  Stream<sb.AuthState> get authChanges => _supabase.authChanges;

  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    String? boleta,
  }) => _guard(() async {
    final response = await _supabase.client.auth.signUp(
      email: _email(email),
      password: password,
      emailRedirectTo: AuthLinkService.confirmationRedirect,
      data: {'name': name.trim(), 'boleta': _optional(boleta?.toUpperCase())},
    );
    // A registration request without a session must never open Home.
    if (response.session == null) return null;
    return _loadProfile(response.user!);
  });

  Future<AppUser> login(String email, String password) => _guard(() async {
    final response = await _supabase.client.auth.signInWithPassword(
      email: _email(email),
      password: password,
    );
    if (response.session == null || response.user == null) {
      throw const AuthException(
        'No se pudo abrir una sesión. Intenta de nuevo.',
      );
    }
    return _loadProfile(response.user!);
  });

  Future<AppUser> confirmEmail(String email, String code) => _guard(() async {
    _requireOtp();
    final response = await _supabase.client.auth.verifyOTP(
      email: _email(email),
      token: code.trim(),
      type: sb.OtpType.email,
    );
    if (response.session == null || response.user == null) {
      throw const AuthException(
        'No se pudo confirmar el correo. Solicita otro código.',
      );
    }
    return _loadProfile(response.user!);
  });

  Future<void> resendConfirmation(String email) => _guard(() async {
    await _supabase.client.auth.resend(
      email: _email(email),
      type: sb.OtpType.signup,
      emailRedirectTo: AuthLinkService.confirmationRedirect,
    );
  });

  Future<AppUser?> signInWithGoogle() async => throw const AuthException(
    'El acceso con Google estará disponible en una fase posterior.',
  );

  Future<AppUser?> restoreSession() => _guard(() async {
    // A legacy locally signed token never authorizes backend access.
    await _secure.deleteToken();
    final client = _supabase.client;
    if (client.auth.currentSession == null) return null;
    if (client.auth.currentSession!.isExpired) {
      await client.auth.refreshSession();
    }
    final response = await client.auth.getUser();
    if (response.user == null) return null;
    return _loadProfile(response.user!);
  });

  Future<void> logout() => _guard(() async {
    await cancelPasswordRecovery();
    await _supabase.client.auth.signOut(scope: sb.SignOutScope.local);
    await _secure.deleteToken();
  });

  Future<void> requestPasswordReset(String email) => _guard(() async {
    await _supabase.client.auth.resetPasswordForEmail(
      _email(email),
      redirectTo: AuthLinkService.recoveryRedirect,
    );
  });

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(() async {
    _requireOtp();
    // This session has no persistent storage and cannot open Home, even when
    // recovery is interrupted by closing the app before the password is saved.
    final recovery = _supabase.createRecoveryClient();
    try {
      final response = await recovery.auth.verifyOTP(
        email: _email(email),
        token: code.trim(),
        type: sb.OtpType.recovery,
      );
      if (response.session == null) {
        throw const AuthException('Código inválido o vencido. Solicita otro.');
      }
      await recovery.auth.updateUser(sb.UserAttributes(password: newPassword));
    } finally {
      try {
        await recovery.auth.signOut(scope: sb.SignOutScope.local);
      } catch (_) {
        // The temporary client has no persistent storage to clear.
      }
      await recovery.dispose();
    }
  });

  /// Validates standard Supabase email links with a non-persistent SDK client.
  /// Returns true only for a verified recovery session, never a Home session.
  Future<bool> openAuthLink(Uri uri) => _guard(() async {
    if (!AuthLinkService.supports(uri)) {
      throw const AuthException('Enlace de autenticación no válido.');
    }
    await cancelPasswordRecovery();
    final temporary = _supabase.createRecoveryClient();
    var keepForRecovery = false;
    try {
      final response = await temporary.auth.getSessionFromUrl(uri);
      final recovery =
          response.redirectType == 'recovery' ||
          response.redirectType == 'passwordRecovery';
      if (recovery != (uri.path == '/recovery') ||
          (!recovery &&
              !(uri.queryParameters.containsKey('code') &&
                  response.redirectType == null) &&
              response.redirectType != 'signup' &&
              response.redirectType != 'email')) {
        throw const AuthException('El enlace no corresponde a esta operación.');
      }
      if (response.session.user.emailConfirmedAt == null) {
        throw const AuthException('El correo todavía no está confirmado.');
      }
      // Remove any older app session before presenting a different account's link.
      await _supabase.client.auth.signOut(scope: sb.SignOutScope.local);
      if (recovery) {
        _recoveryClient = temporary;
        keepForRecovery = true;
      }
      return recovery;
    } finally {
      if (!keepForRecovery) await _disposeTemporary(temporary);
    }
  });

  Future<void> finishPasswordRecovery(String newPassword) => _guard(() async {
    final recovery = _recoveryClient;
    if (recovery == null || recovery.auth.currentSession == null) {
      throw const AuthException(
        'Abre un enlace de recuperación válido desde tu correo.',
      );
    }
    await recovery.auth.updateUser(sb.UserAttributes(password: newPassword));
    await cancelPasswordRecovery();
  });

  Future<void> cancelPasswordRecovery() async {
    final recovery = _recoveryClient;
    _recoveryClient = null;
    if (recovery != null) await _disposeTemporary(recovery);
  }

  Future<void> _disposeTemporary(sb.SupabaseClient temporary) async {
    try {
      await temporary.auth.signOut(scope: sb.SignOutScope.local);
    } catch (_) {
      // No persistent storage belongs to this temporary client.
    }
    await temporary.dispose();
  }

  void _requireOtp() {
    if (!emailOtpEnabled) {
      throw const AuthException(
        'Usa el enlace enviado por correo. '
        'Los códigos de autenticación requieren SMTP y plantillas configuradas.',
      );
    }
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final client = _supabase.client;
    final current = client.auth.currentUser;
    if (current == null || current.id != userId || current.email == null) {
      throw const AuthException(
        'Vuelve a iniciar sesión para cambiar la contraseña.',
      );
    }
    await client.auth.signInWithPassword(
      email: current.email!,
      password: currentPassword,
    );
    await client.auth.updateUser(sb.UserAttributes(password: newPassword));
  });

  Future<AppUser> updateProfile(AppUser user) => _guard(() async {
    final client = _supabase.client;
    if (client.auth.currentUser?.id != user.id) {
      throw const AuthException('La sesión no corresponde a este perfil.');
    }
    await client
        .from('profiles')
        .update({
          'name': user.name.trim(),
          'boleta': _optional(user.boleta?.toUpperCase()),
          'phone': _optional(user.phone),
          'notifications_enabled': user.notificationsEnabled,
          'dark_mode': user.darkMode,
        })
        .eq('id', user.id)
        .select('id')
        .single();
    await _cacheUser(user);
    return _loadProfile(client.auth.currentUser!);
  });

  Future<AppUser> _loadProfile(sb.User identity) async {
    final row = await _supabase.client
        .from('profiles')
        .select()
        .eq('id', identity.id)
        .maybeSingle();
    if (row == null) {
      throw const StorageException(
        'No existe tu perfil en Supabase. '
        'Pide al administrador ejecutar la migración de profiles.',
      );
    }
    final db = await _database.database;
    final cached = await db.query(
      'users',
      columns: ['avatar_path'],
      where: 'id = ?',
      whereArgs: [identity.id],
      limit: 1,
    );
    final user = AppUser(
      id: identity.id,
      name: row['name'] as String,
      email: identity.email ?? '',
      provider: 'supabase',
      createdAt: DateTime.parse(identity.createdAt),
      boleta: row['boleta'] as String?,
      phone: row['phone'] as String?,
      avatarPath: cached.isEmpty
          ? null
          : cached.first['avatar_path'] as String?,
      notificationsEnabled: row['notifications_enabled'] as bool,
      darkMode: row['dark_mode'] as bool,
    );
    await _cacheUser(user);
    return user;
  }

  Future<void> _cacheUser(AppUser user) async {
    final db = await _database.database;
    // Preserve legacy accounts and their report ownership even if an email
    // matches. This internal cache address is never displayed or sent to Auth.
    final values = {
      ...user.toMap(),
      'email': '${user.id}@supabase.local.invalid',
    };
    await db.transaction((txn) async {
      final count = await txn.update(
        'users',
        values,
        where: 'id = ?',
        whereArgs: [user.id],
      );
      if (count == 0) await txn.insert('users', values);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on sb.AuthException catch (e) {
      if (e.message == 'Code verifier could not be found in local storage.') {
        throw const AuthException(
          'Solicita el enlace desde este celular y vuelve a abrirlo aquí. '
          'Si ya confirmaste el correo, intenta iniciar sesión con tu contraseña.',
        );
      }
      final message = switch (e.code) {
        'invalid_credentials' => 'Correo o contraseña incorrectos.',
        'email_not_confirmed' => 'Confirma tu correo antes de iniciar sesión.',
        'user_already_exists' ||
        'email_exists' => 'Ya existe una cuenta con ese correo.',
        'weak_password' =>
          'La contraseña no cumple los requisitos de seguridad.',
        'same_password' => 'Elige una contraseña diferente a la anterior.',
        'otp_expired' ||
        'otp_disabled' => 'Código inválido o vencido. Solicita otro.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Espera un momento antes de solicitar otro correo o intentar de nuevo.',
        'email_address_invalid' => 'Escribe un correo electrónico válido.',
        'email_address_not_authorized' =>
          'El servicio de correo aún no permite '
              'este destinatario. El administrador debe configurar SMTP en Supabase.',
        'signup_disabled' => 'El registro está deshabilitado en Supabase.',
        'session_not_found' ||
        'refresh_token_not_found' ||
        'refresh_token_already_used' =>
          'Tu sesión venció. Vuelve a iniciar sesión.',
        _ =>
          'No se pudo completar la autenticación. Revisa tu conexión, '
              'el código recibido y vuelve a intentarlo.',
      };
      throw AuthException(message, cause: e);
    } on sb.PostgrestException catch (e) {
      throw StorageException(
        'No se pudo acceder a tu perfil en Supabase. '
        'Revisa la migración de profiles y sus políticas RLS.',
        cause: e,
      );
    } on DatabaseException catch (e) {
      throw StorageException(
        'No se pudo guardar el perfil en este dispositivo.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'No hay conexión con Supabase. Revisa tu conexión a internet.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw NetworkException(
        'No hay conexión con Supabase. Revisa tu conexión a internet.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Supabase tardó demasiado en responder. Intenta de nuevo.',
        cause: e,
      );
    }
  }

  String _email(String value) => value.trim().toLowerCase();
  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
