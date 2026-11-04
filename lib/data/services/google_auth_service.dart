import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';

class GoogleProfile {
  const GoogleProfile({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
}

/// Proveedor OAuth externo (Google) para el ingreso (RF1).
///
/// El client ID se inyecta con `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`;
/// no hay credenciales en el código.
class GoogleAuthService {
  bool _initialized = false;

  bool get isAvailable => Env.googleSignInEnabled;

  Future<GoogleProfile?> signIn() async {
    if (!isAvailable) {
      throw const AuthException('El inicio con Google no está configurado.');
    }
    try {
      if (!_initialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: Env.googleServerClientId,
        );
        _initialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      return GoogleProfile(
        id: account.id,
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException('No se pudo iniciar sesión con Google.', cause: e);
    } catch (e) {
      throw AuthException('No se pudo iniciar sesión con Google.', cause: e);
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
