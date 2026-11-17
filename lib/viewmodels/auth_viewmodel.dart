import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/errors/app_exception.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/auth_link_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }

/// Only backend sessions authorize access through the existing AuthGate.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository, {AuthLinkService? links}) : _links = links {
    _linkSubscription = links?.events.listen((_) => unawaited(_consumeLink()));
    _subscription = _repository.authChanges.listen(
      (state) {
        if (state.event == sb.AuthChangeEvent.signedOut) {
          _sessionRevision++;
          if (_consumingLink) return;
          _setUser(null);
          _notify();
        }
      },
      onError: (Object error) {
        _sessionRevision++;
        _setUser(null);
        _error =
            'No se pudo renovar la sesión. Revisa tu conexión e inicia sesión de nuevo.';
        _notify();
      },
    );
  }

  final AuthRepository _repository;
  final AuthLinkService? _links;
  StreamSubscription<void>? _linkSubscription;
  bool _restoring = false;
  bool _consumingLink = false;
  late final StreamSubscription<sb.AuthState> _subscription;
  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  bool _disposed = false;
  int _sessionRevision = 0;
  String? _error;
  String? _notice;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  String? get notice => _notice;
  bool get emailOtpEnabled => _repository.emailOtpEnabled;
  bool get googleAvailable => _repository.googleAvailable;

  Future<void> restoreSession() async {
    if (_links?.hasPending ?? false) {
      await _consumeLink();
      return;
    }
    _restoring = true;
    final revision = ++_sessionRevision;
    try {
      final user = await _repository.restoreSession();
      if (revision == _sessionRevision) _setUser(user);
    } catch (e) {
      if (revision == _sessionRevision) {
        _setUser(null);
        _error = userMessageFor(e);
      }
    }
    _restoring = false;
    _error ??= _links?.initializationError;
    _notify();
    unawaited(_consumeLink());
  }

  Future<void> _consumeLink() async {
    if (_busy ||
        _restoring ||
        _consumingLink ||
        !(_links?.hasPending ?? false)) {
      return;
    }
    _consumingLink = true;
    final uri = _links!.takePending()!;
    _sessionRevision++;
    final ok = await _runVoid(() async {
      final recovery = await _repository.openAuthLink(uri);
      _user = null;
      _status = recovery
          ? AuthStatus.passwordRecovery
          : AuthStatus.unauthenticated;
      _notice = recovery
          ? null
          : 'Correo confirmado. Inicia sesión con tu contraseña.';
    });
    if (!ok) {
      _setUser(null);
      _notify();
    }
    _consumingLink = false;
    unawaited(_consumeLink());
  }

  Future<bool> login(String email, String password) =>
      _runUser(() => _repository.login(email, password));

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? boleta,
  }) => _runVoid(() async {
    final revision = _sessionRevision;
    final user = await _repository.register(
      name: name,
      email: email,
      password: password,
      boleta: boleta,
    );
    if (revision != _sessionRevision) {
      throw const AuthException('La sesión terminó. Vuelve a iniciar sesión.');
    }
    _setUser(user);
  });

  Future<bool> confirmEmail(String email, String code) =>
      _runUser(() => _repository.confirmEmail(email, code));

  Future<bool> resendConfirmation(String email) =>
      _runVoid(() => _repository.resendConfirmation(email));

  Future<bool> signInWithGoogle() => _runUser(_repository.signInWithGoogle);

  Future<bool> logout() => _runVoid(() async {
    await _repository.logout();
    _sessionRevision++;
    _setUser(null);
  });

  Future<bool> requestPasswordReset(String email) =>
      _runVoid(() => _repository.requestPasswordReset(email));

  Future<bool> finishPasswordRecovery(String password) => _runVoid(() async {
    await _repository.finishPasswordRecovery(password);
    _setUser(null);
    _notice = 'Contraseña actualizada. Inicia sesión con tu nueva contraseña.';
  });

  Future<bool> cancelPasswordRecovery() => _runVoid(() async {
    await _repository.cancelPasswordRecovery();
    _setUser(null);
  });

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _runVoid(
    () => _repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    ),
  );

  void updateUser(AppUser user) {
    if (_user?.id != user.id) return;
    _user = user;
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  Future<bool> _runUser(Future<AppUser?> Function() action) =>
      _runVoid(() async {
        final revision = _sessionRevision;
        final user = await action();
        if (revision != _sessionRevision || user == null) {
          throw const AuthException(
            'La sesión terminó. Vuelve a iniciar sesión.',
          );
        }
        _setUser(user);
      });

  Future<bool> _runVoid(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _notice = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      _error = userMessageFor(e);
      return false;
    } finally {
      _busy = false;
      _notify();
      unawaited(_consumeLink());
    }
  }

  void _setUser(AppUser? user) {
    _user = user;
    _status = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_linkSubscription?.cancel());
    unawaited(_repository.cancelPasswordRecovery());
    super.dispose();
  }
}
