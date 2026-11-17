import 'package:flutter/material.dart';

import '../features/splash/presentation/splash_screen.dart';

/// Entrada compatible con las vistas existentes; la presentación vive en splash.
class SplashView extends StatelessWidget {
  const SplashView({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onFinished: onFinished);
  }
}
