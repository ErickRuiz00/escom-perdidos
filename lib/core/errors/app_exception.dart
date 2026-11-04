/// Excepción de la aplicación con un mensaje apto para mostrarse al usuario.
///
/// Las capas de datos traducen errores técnicos (SQLite, red, plugins) a esta
/// clase para que las vistas nunca muestren trazas ni mensajes crípticos.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message${cause != null ? ' ($cause)' : ''}';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.cause});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// Convierte cualquier error en un mensaje entendible.
String userMessageFor(Object error) {
  if (error is AppException) return error.message;
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
