import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/errors/error_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/local/secure_store.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/location_service.dart';
import 'data/services/media_service.dart';
import 'data/services/notification_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/reports_viewmodel.dart';
import 'viewmodels/weather_viewmodel.dart';
import 'views/auth/login_view.dart';
import 'views/home/home_shell.dart';
import 'views/splash_view.dart';

/// Raíz de la app: registra las dependencias (servicios → repositorios →
/// ViewModels) y elige la pantalla inicial según el estado de la sesión.
class EscomPerdidosApp extends StatelessWidget {
  const EscomPerdidosApp({
    super.key,
    required this.database,
    required this.secureStore,
    required this.notifications,
  });

  final AppDatabase database;
  final SecureStore secureStore;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios y repositorios (se crean una sola vez).
        Provider.value(value: notifications),
        Provider(create: (_) => MediaService()),
        Provider(create: (_) => LocationService()),
        Provider(
          create: (_) => AuthRepository(database: database, secureStore: secureStore),
        ),
        // ViewModels.
        ChangeNotifierProvider(
          create: (context) =>
              AuthViewModel(context.read<AuthRepository>(), notifications)
                ..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (context) => ProfileViewModel(
            repository: context.read<AuthRepository>(),
            auth: context.read<AuthViewModel>(),
            media: context.read<MediaService>(),
            notifications: notifications,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReportsViewModel(
            repository: ReportRepository(database),
            notifications: notifications,
            media: context.read<MediaService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherViewModel(
            WeatherRepository(database: database, api: ApiClient()),
          ),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthViewModel, AuthStatus>((a) => a.status);
    final dark = context.select<AuthViewModel, bool>((a) => a.user?.darkMode ?? false);

    return MaterialApp(
      title: 'Encuéntralo ESCOM',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalErrorHandler.messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (status) {
          AuthStatus.unknown => const SplashView(),
          AuthStatus.unauthenticated => const LoginView(),
          AuthStatus.authenticated => const HomeShell(),
        },
      ),
    );
  }
}
