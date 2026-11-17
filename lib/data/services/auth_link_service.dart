import 'dart:async';

import 'package:app_links/app_links.dart';

/// Receives only this app's Auth callbacks, including a cold-start callback.
/// Supabase validates the actual tokens later; receiving a URI proves nothing.
class AuthLinkService {
  static const confirmationRedirect = 'mx.ipn.escom.encuentralo://auth/confirm';
  static const recoveryRedirect = 'mx.ipn.escom.encuentralo://auth/recovery';

  final _events = StreamController<void>.broadcast();
  StreamSubscription<Uri>? _subscription;
  Uri? _pending;
  Uri? _lastReceived;
  String? initializationError;

  Stream<void> get events => _events.stream;

  static bool supports(Uri uri) =>
      uri.scheme == 'mx.ipn.escom.encuentralo' &&
      uri.host == 'auth' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      (uri.path == '/confirm' || uri.path == '/recovery');

  Future<void> initialize() async {
    try {
      final links = AppLinks();
      _subscription = links.uriLinkStream.listen(
        receive,
        onError: (Object _) {
          initializationError =
              'No se pudo recibir el enlace de correo. '
              'Cierra y vuelve a abrir la aplicación antes de intentarlo otra vez.';
        },
      );
      receive(await links.getInitialLink());
    } catch (_) {
      initializationError =
          'No se pudieron activar los enlaces de correo en este dispositivo.';
    }
  }

  void receive(Uri? uri) {
    if (uri == null || !supports(uri) || uri == _lastReceived) return;
    _lastReceived = uri;
    _pending = uri;
    _events.add(null);
  }

  bool get hasPending => _pending != null;

  Uri? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _events.close();
  }
}
