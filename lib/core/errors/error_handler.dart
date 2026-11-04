import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manejo global de excepciones (RNF2 - Confiabilidad).
///
/// Captura errores del framework, de la zona y de la plataforma para que un
/// fallo de red, de base de datos o de un plugin nunca cierre la app.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _log(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _log(error, stack);
      return true; // Marcado como manejado: evita el crash.
    };

    // En lugar de la pantalla roja, se muestra un aviso amable.
    ErrorWidget.builder = (details) => const _FriendlyErrorWidget();
  }

  /// Ejecuta la app dentro de una zona protegida.
  static void runGuarded(Future<void> Function() body) {
    runZonedGuarded(body, _log);
  }

  static void _log(Object error, StackTrace? stack) {
    debugPrint('[GlobalErrorHandler] $error');
    if (stack != null && kDebugMode) debugPrint('$stack');
  }

  /// Muestra un mensaje breve al usuario desde cualquier capa.
  static void showMessage(String message, {bool isError = false}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    final colors = Theme.of(messenger.context).colorScheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : null,
        behavior: SnackBarBehavior.floating,
      ));
  }
}

class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No pudimos mostrar esta sección.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
