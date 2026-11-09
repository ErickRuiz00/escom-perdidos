import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import 'auth_theme.dart';
import 'auth_widgets.dart';
import 'particle_globe.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  void _open(BuildContext context, String route) {
    context.read<AuthViewModel>().clearError();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5, -0.5),
              radius: 1.1,
              colors: [Color(0xFF3C1D33), AuthTheme.background],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroHeight = (constraints.maxHeight * 0.39).clamp(
                  250.0,
                  340.0,
                );
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AuthBrand(),
                            SizedBox(
                              height: heroHeight,
                              child: reduceMotion
                                  ? Semantics(
                                      image: true,
                                      label: 'Globo de la comunidad ESCOM',
                                      child: const GlobeFallback(),
                                    )
                                  : const ParticleGlobe(),
                            ),
                            AuthEntrance(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Encuéntralo',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 42,
                                      height: 1.12,
                                      letterSpacing: -1.3,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ESCOM',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      letterSpacing: 6,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const GoogleAccessButton(),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => _open(context, '/login'),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 20,
                                    ),
                                    label: const Text('Iniciar con correo'),
                                  ),
                                  const SizedBox(height: 12),
                                  AccountLink(
                                    prompt: '¿No tienes cuenta?',
                                    label: 'Regístrate',
                                    onPressed: () =>
                                        _open(context, '/register'),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Globo adaptado de sm_motion · CC BY 4.0',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
