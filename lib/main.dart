import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/errors/error_handler.dart';
import 'data/local/app_database.dart';
import 'data/local/secure_store.dart';
import 'data/services/notification_service.dart';
import 'data/services/supabase_service.dart';
import 'data/services/auth_link_service.dart';

Future<void> main() async {
  GlobalErrorHandler.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.install();
    await initializeDateFormatting('es_MX');

    final supabase = SupabaseService();
    await supabase.initialize();
    final authLinks = AuthLinkService();
    await authLinks.initialize();

    final database = AppDatabase();
    final notifications = NotificationService();
    await notifications.init();

    runApp(
      EscomPerdidosApp(
        database: database,
        secureStore: SecureStore(),
        notifications: notifications,
        supabase: supabase,
        authLinks: authLinks,
      ),
    );
  });
}
