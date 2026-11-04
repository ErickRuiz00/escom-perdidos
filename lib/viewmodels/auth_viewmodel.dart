import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/notification_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Estado de la sesión del usuario (RF1). Las vistas escuchan este ViewModel
/// para decidir si muestran el login o la app.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository, this._notifications);

  final AuthRepository _repository;
  final NotificationService _notifications;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  bool get googleAvailable => _repository.googleAvailable;

  Future<void> restoreSession() async {
    try {
      _user = await _repository.restoreSession();
    } catch (_) {
      _user = null;
    }
    _status = _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) =>
      _run(() => _repository.login(email, password));

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? boleta,
  }) =>
      _run(() => _repository.register(
            name: name,
            email: email,
            password: password,
            boleta: boleta,
          ));

  Future<bool> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Envía el código de recuperación como notificación local
  /// (simula el correo que enviaría un servidor).
  Future<bool> requestPasswordReset(String email) async {
    return _runVoid(() async {
      final code = await _repository.requestPasswordReset(email);
      await _notifications.requestPermission();
      await _notifications.show(
        title: 'Código de recuperación',
        body: 'Tu código es $code. Vence en 15 minutos.',
      );
    });
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _runVoid(() => _repository.resetPassword(
            email: email,
            code: code,
            newPassword: newPassword,
          ));

  /// Lo usa el perfil cuando el usuario edita sus datos.
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<AppUser?> Function() action) async {
    _setBusy(true);
    try {
      final user = await action();
      if (user == null) return false; // Flujo cancelado por el usuario.
      _user = user;
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _error = userMessageFor(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> _runVoid(Future<void> Function() action) async {
    _setBusy(true);
    try {
      await action();
      return true;
    } catch (e) {
      _error = userMessageFor(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    if (value) _error = null;
    notifyListeners();
  }
}
