import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/errors/error_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/local/secure_store.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/found_items_repository.dart';
import 'data/repositories/recovery_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/location_service.dart';
import 'data/services/media_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/supabase_service.dart';
import 'data/services/auth_link_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/reports_viewmodel.dart';
import 'viewmodels/recovery_viewmodel.dart';
import 'viewmodels/weather_viewmodel.dart';
import 'views/auth/auth_flow.dart';

/// Raíz de la app: registra las dependencias (servicios → repositorios →
/// ViewModels) y elige la pantalla inicial según el estado de la sesión.
class EscomPerdidosApp extends StatelessWidget {
  const EscomPerdidosApp({
    super.key,
    required this.database,
    required this.secureStore,
    required this.notifications,
    required this.supabase,
    required this.authLinks,
  });

  final AppDatabase database;
  final SecureStore secureStore;
  final NotificationService notifications;
  final SupabaseService supabase;
  final AuthLinkService authLinks;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios y repositorios (se crean una sola vez).
        Provider.value(value: notifications),
        Provider(create: (_) => MediaService()),
        Provider(create: (_) => LocationService()),
        Provider(
          create: (_) => AuthRepository(
            database: database,
            secureStore: secureStore,
            supabase: supabase,
          ),
        ),
        // ViewModels.
        ChangeNotifierProvider(
          create: (context) =>
              AuthViewModel(context.read<AuthRepository>(), links: authLinks)
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
        ChangeNotifierProxyProvider<AuthViewModel, ReportsViewModel>(
          create: (context) =>
              ReportsViewModel(repository: FoundItemsRepository(supabase)),
          update: (_, auth, reports) => reports!..bindUser(auth.user?.id),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherViewModel(
            WeatherRepository(database: database, api: ApiClient()),
          ),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, RecoveryViewModel>(
          create: (context) => RecoveryViewModel(
            repository: RecoveryRepository(supabase),
            onItemChanged: context.read<ReportsViewModel>().load,
          ),
          update: (_, auth, recovery) => recovery!..bindUser(auth.user?.id),
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
    final dark = context.select<AuthViewModel, bool?>((a) => a.user?.darkMode);

    return MaterialApp(
      title: 'Encuéntralo ESCOM',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalErrorHandler.messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark == null
          ? ThemeMode.system
          : dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(Theme.of(context)),
        child: child!,
      ),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
