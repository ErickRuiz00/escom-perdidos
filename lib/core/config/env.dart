/// Configuración de entorno inyectada en tiempo de compilación.
///
/// Ningún secreto ni llave se escribe en el código fuente (RNF2 - Seguridad).
/// Los valores se pasan con `--dart-define`, por ejemplo:
///
/// ```
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
/// ```
class Env {
  Env._();

  /// Client ID (tipo "Web") de Google Cloud para el inicio de sesión OAuth.
  /// Si está vacío, el botón de Google se muestra deshabilitado.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// URL base del servicio de clima. Debe ser HTTPS.
  static const weatherBaseUrl = String.fromEnvironment(
    'WEATHER_BASE_URL',
    defaultValue: 'https://api.open-meteo.com/v1/forecast',
  );

  static bool get googleSignInEnabled => googleServerClientId.isNotEmpty;
}
