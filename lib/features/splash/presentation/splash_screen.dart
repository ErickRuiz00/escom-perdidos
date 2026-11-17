import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import 'animated_circuit_logo.dart';
import 'splash_progress_bar.dart';

/// Presentación inicial. AuthGate conserva la decisión de acceso y navegación.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  static const duration = Duration(milliseconds: 2700);

  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashScreen.duration,
    // El movimiento reducido cambia la presentación, no la espera de arranque.
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);

  late final Animation<double> _entry = _interval(0, 0.16);
  late final Animation<double> _circuit = _interval(0.10, 0.69, Curves.linear);
  late final Animation<double> _title = _interval(0.64, 0.80);
  late final Animation<double> _subtitle = _interval(0.72, 0.87);
  late final Animation<double> _progress = _interval(0.77, 0.96);

  Animation<double> _interval(
    double start,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) =>
      _controller.drive(CurveTween(curve: Interval(start, end, curve: curve)));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const visible = AlwaysStoppedAnimation<double>(1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle(theme),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: reduceMotion ? visible : _entry,
                                child: ScaleTransition(
                                  scale: reduceMotion
                                      ? visible
                                      : _entry.drive(
                                          Tween(begin: 0.90, end: 1),
                                        ),
                                  child: AnimatedCircuitLogo(
                                    size: math.min(
                                      184,
                                      constraints.maxWidth * 0.48,
                                    ),
                                    progress: reduceMotion ? visible : _circuit,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              FadeTransition(
                                opacity: reduceMotion ? visible : _title,
                                child: Text(
                                  'Encuéntralo ESCOM',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FadeTransition(
                                opacity: reduceMotion ? visible : _subtitle,
                                child: Text(
                                  'Objetos perdidos y encontrados · IPN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              FadeTransition(
                                opacity: reduceMotion ? visible : _subtitle,
                                child: SplashProgressBar(
                                  progress: reduceMotion ? visible : _progress,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28, top: 16),
                          child: Text(
                            'COMUNIDAD ESTUDIANTIL ESCOM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.6,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
