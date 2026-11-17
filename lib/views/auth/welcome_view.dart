import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'auth_widgets.dart';

/// Acceso sencillo, sin el globo ni controles de objetos escolares.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  void _open(BuildContext context, String route) {
    context.read<AuthViewModel>().clearError();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 36,
                      ),
                      child: AuthEntrance(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AuthBrand(),
                            const SizedBox(height: 48),
                            Text(
                              'Encuéntralo',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ESCOM',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                letterSpacing: 6,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Objetos perdidos y encontrados · IPN',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ErrorBanner(
                              message: context.watch<AuthViewModel>().error,
                            ),
                            if (context.watch<AuthViewModel>().notice
                                case final notice?)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  notice,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: () => _open(context, '/login'),
                              icon: const Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                              ),
                              label: const Text('Iniciar con correo'),
                            ),
                            const SizedBox(height: 16),
                            const GoogleAccessButton(),
                            const SizedBox(height: 12),
                            AccountLink(
                              prompt: '¿No tienes cuenta?',
                              label: 'Regístrate',
                              onPressed: () => _open(context, '/register'),
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
        ),
      ),
    );
  }
}
