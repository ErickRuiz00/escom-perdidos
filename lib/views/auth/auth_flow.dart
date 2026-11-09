import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../home/home_shell.dart';
import '../splash_view.dart';
import 'auth_theme.dart';
import 'forgot_password_view.dart';
import 'login_view.dart';
import 'register_view.dart';
import 'welcome_view.dart';

/// La pila de acceso desaparece completa al abrir una sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.authenticated = const HomeShell()});

  final Widget authenticated;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthViewModel, AuthStatus>((vm) => vm.status);
    // No se retiene la pantalla saliente: evita animar o exponer formularios
    // y datos privados después de cambiar el estado de la sesión.
    return switch (status) {
      AuthStatus.unknown => const SplashView(),
      AuthStatus.unauthenticated => const AuthFlow(),
      AuthStatus.authenticated => authenticated,
    };
  }
}

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AuthTheme(
      child: NavigatorPopHandler(
        onPopWithResult: (_) => _navigatorKey.currentState!.pop(),
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (settings) {
            final page = switch (settings.name) {
              '/login' => const LoginView(),
              '/register' => const RegisterView(),
              '/forgot-password' => const ForgotPasswordView(),
              _ => const WelcomeView(),
            };
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            return PageRouteBuilder<void>(
              settings: settings,
              transitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              reverseTransitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              pageBuilder: (_, _, _) => page,
              transitionsBuilder: (_, animation, _, child) {
                final curved = animation.drive(
                  CurveTween(curve: Curves.easeOutCubic),
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: curved.drive(
                      Tween(begin: const Offset(0.04, 0), end: Offset.zero),
                    ),
                    child: child,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
