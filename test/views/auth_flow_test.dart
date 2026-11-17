import 'dart:async';

import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/services/notification_service.dart';
import 'package:escom_perdidos/features/splash/presentation/animated_circuit_logo.dart';
import 'package:escom_perdidos/features/splash/presentation/splash_progress_bar.dart';
import 'package:escom_perdidos/features/splash/presentation/splash_screen.dart';
import 'package:escom_perdidos/viewmodels/auth_viewmodel.dart';
import 'package:escom_perdidos/views/auth/auth_flow.dart';
import 'package:escom_perdidos/views/auth/login_view.dart';
import 'package:escom_perdidos/views/auth/register_view.dart';
import 'package:escom_perdidos/views/auth/welcome_view.dart';
import 'package:escom_perdidos/views/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final _user = AppUser(
  id: 'student',
  name: 'Ana López',
  email: 'ana@ipn.mx',
  provider: 'local',
  createdAt: DateTime(2026),
);

/// Dobles solo en pruebas: la aplicación utiliza su repositorio real.
class _AuthRepository implements AuthRepository {
  Completer<AppUser?>? pendingRestore;
  bool rejectLogin = false;
  int loginCalls = 0;
  int registerCalls = 0;
  int resetCalls = 0;

  @override
  Future<AppUser?> restoreSession() async => pendingRestore?.future;

  @override
  Future<AppUser> login(String email, String password) async {
    loginCalls++;
    if (rejectLogin) {
      throw const AuthException('Correo o contraseña incorrectos.');
    }
    return _user;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? boleta,
  }) async {
    registerCalls++;
    return _user;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String> requestPasswordReset(String email) async => '123456';

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    expect(code, '123456');
    resetCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  AuthViewModel vm, {
  bool reduceMotion = true,
  double textScale = 1,
  double keyboard = 0,
  bool finishSplash = true,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: vm,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: const AuthGate(
          authenticated: Scaffold(body: Text('Área privada')),
        ),
      ),
    ),
  );
  await tester.pump();
  if (finishSplash) {
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late _AuthRepository repository;
  late AuthViewModel vm;

  setUp(() {
    repository = _AuthRepository();
    vm = AuthViewModel(repository, NotificationService());
  });

  tearDown(() => vm.dispose());

  testWidgets('cambiar de tema conserva el login y el texto escrito', (
    tester,
  ) async {
    await vm.restoreSession();
    await _pump(tester, vm);
    await _tap(tester, 'Iniciar con correo');
    await tester.enterText(find.byType(TextFormField).first, 'ana@ipn.mx');
    await _pump(tester, vm, dark: true);
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('ana@ipn.mx'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(LoginView))).brightness,
      Brightness.dark,
    );
    await _pump(tester, vm);
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('ana@ipn.mx'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(LoginView))).brightness,
      Brightness.light,
    );
  });

  testWidgets('sesión resuelta conserva la splash durante 2.7 segundos', (
    tester,
  ) async {
    await vm.restoreSession();
    await _pump(tester, vm, finishSplash: false);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(WelcomeView), findsNothing);

    await tester.pump(const Duration(milliseconds: 2699));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(WelcomeView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen, skipOffstage: false), findsNothing);
  });

  testWidgets(
    'restauración lenta espera sin mostrar acceso ni datos privados',
    (tester) async {
      repository.pendingRestore = Completer<AppUser?>();
      unawaited(vm.restoreSession());
      await _pump(tester, vm, finishSplash: false);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(WelcomeView), findsNothing);
      expect(find.text('Área privada'), findsNothing);

      repository.pendingRestore!.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );

  testWidgets('restauración rápida abre sesión después de la splash una vez', (
    tester,
  ) async {
    repository.pendingRestore = Completer<AppUser?>();
    unawaited(vm.restoreSession());
    await _pump(tester, vm, finishSplash: false);
    repository.pendingRestore!.complete(_user);
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Área privada'), findsNothing);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.text('Área privada'), findsOneWidget);
    await vm.logout();
    await tester.pump();
    expect(find.byType(WelcomeView), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('circuito se ilumina antes de llenar la barra de apertura', (
    tester,
  ) async {
    await _pump(tester, vm, finishSplash: false, reduceMotion: false);
    double circuit() => tester
        .widget<AnimatedCircuitLogo>(find.byType(AnimatedCircuitLogo))
        .progress
        .value;
    double progress() => tester
        .widget<SplashProgressBar>(find.byType(SplashProgressBar))
        .progress
        .value;

    expect(circuit(), 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(circuit(), inExclusiveRange(0, 1));
    expect(progress(), 0);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(circuit(), 1);
    expect(progress(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress(), 1);
  });

  testWidgets('splash admite texto al 200 %, pantalla pequeña y poco alto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, vm, finishSplash: false, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Encuéntralo ESCOM'), findsOneWidget);
    await tester.ensureVisible(find.text('COMUNIDAD ESTUDIANTIL ESCOM'));
    expect(tester.takeException(), isNull);
    await tester.pump(SplashScreen.duration);
    expect(tester.takeException(), isNull);
  });

  testWidgets('movimiento reducido muestra el logo completo sin animarlo', (
    tester,
  ) async {
    await _pump(tester, vm, finishSplash: false);
    final logo = tester.widget<AnimatedCircuitLogo>(
      find.byType(AnimatedCircuitLogo),
    );
    expect(logo.progress.value, 1);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(logo.progress.value, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(SplashScreen.duration);
  });

  testWidgets(
    'desmontar la splash libera animaciones y no llama al finalizar',
    (tester) async {
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SplashScreen(onFinished: () => completions++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(completions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'espera la restauración; sesión válida omite bienvenida y logout vuelve',
    (tester) async {
      repository.pendingRestore = Completer<AppUser?>();
      unawaited(vm.restoreSession());
      await _pump(tester, vm);
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.byType(WelcomeView), findsNothing);
      repository.pendingRestore!.complete(_user);
      await tester.pumpAndSettle();
      expect(find.text('Área privada'), findsOneWidget);
      expect(find.byType(WelcomeView), findsNothing);
      await vm.logout();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
      final google = tester.widget<FilledButton>(
        find.byWidgetPredicate(
          (widget) => widget is FilledButton && widget.onPressed == null,
        ),
      );
      expect(google.onPressed, isNull);
    },
  );

  testWidgets(
    'login valida, muestra errores y elimina toda la pila al entrar',
    (tester) async {
      await vm.restoreSession();
      await _pump(tester, vm);
      await _tap(tester, 'Iniciar con correo');
      await _tap(tester, 'Iniciar sesión');
      expect(repository.loginCalls, 0);
      expect(find.text('El correo es obligatorio'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'ana@ipn.mx');
      await tester.enterText(find.byType(TextFormField).at(1), 'Escom2026');
      repository.rejectLogin = true;
      await _tap(tester, 'Iniciar sesión');
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      repository.rejectLogin = false;
      await _tap(tester, 'Iniciar sesión');
      expect(find.text('Área privada'), findsOneWidget);
      expect(find.byType(LoginView, skipOffstage: false), findsNothing);
      expect(find.byType(WelcomeView, skipOffstage: false), findsNothing);
      await vm.logout();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.byType(LoginView, skipOffstage: false), findsNothing);
    },
  );

  testWidgets('registro conserva confirmación de contraseña y abre sesión', (
    tester,
  ) async {
    await vm.restoreSession();
    await _pump(tester, vm);
    await _tap(tester, 'Regístrate');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ana López');
    await tester.enterText(fields.at(1), 'ana@ipn.mx');
    await tester.enterText(fields.at(3), 'Escom2026');
    await tester.enterText(fields.at(4), 'Otra2026');
    await _tap(tester, 'Crear cuenta');
    expect(repository.registerCalls, 0);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    await tester.enterText(fields.at(4), 'Escom2026');
    await _tap(tester, 'Crear cuenta');
    expect(repository.registerCalls, 1);
    expect(find.text('Área privada'), findsOneWidget);
    expect(find.byType(RegisterView, skipOffstage: false), findsNothing);
  });

  testWidgets(
    'cambia login/registro sin acumular pantallas y Atrás vuelve a bienvenida',
    (tester) async {
      await vm.restoreSession();
      await _pump(tester, vm);
      await _tap(tester, 'Iniciar con correo');
      await _tap(tester, 'Regístrate');
      expect(find.byType(LoginView, skipOffstage: false), findsNothing);
      await _tap(tester, 'Inicia sesión');
      expect(find.byType(RegisterView, skipOffstage: false), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
    },
  );

  testWidgets(
    'recuperación mantiene código, nueva contraseña y regreso al login',
    (tester) async {
      await vm.restoreSession();
      await _pump(tester, vm);
      await _tap(tester, 'Iniciar con correo');
      await _tap(tester, '¿Olvidaste tu contraseña?');
      await tester.enterText(find.byType(TextFormField).first, 'ana@ipn.mx');
      await _tap(tester, 'Enviar código');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), 'Nueva2026');
      await _tap(tester, 'Restablecer contraseña');
      expect(repository.resetCalls, 1);
      expect(find.byType(LoginView), findsOneWidget);
      expect(vm.status, AuthStatus.unauthenticated);
    },
  );

  testWidgets(
    'pantalla pequeña, texto grande y teclado permiten desplazar formularios',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await vm.restoreSession();
      await _pump(tester, vm, textScale: 2, keyboard: 240);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Regístrate');
      await _tap(tester, 'Crear cuenta');
      expect(tester.takeException(), isNull);
      expect(repository.registerCalls, 0);
      await _tap(tester, 'Inicia sesión');
      await _tap(tester, 'Iniciar sesión');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bienvenida sin animación escolar ni assets permite abrir login',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (_) async => null);
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );

      await vm.restoreSession();
      await _pump(tester, vm, reduceMotion: false);
      // Los botones no esperan la carga ni la animación de entrada.
      await tester.ensureVisible(find.text('Iniciar con correo'));
      await tester.tap(find.text('Iniciar con correo'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byKey(const Key('school-object-globe')), findsNothing);
      expect(find.textContaining('sm_motion'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
