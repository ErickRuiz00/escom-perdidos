import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/errors/error_handler.dart';
import 'data/local/app_database.dart';
import 'data/local/secure_store.dart';
import 'data/local/seed_data.dart';
import 'data/services/notification_service.dart';

Future<void> main() async {
  GlobalErrorHandler.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.install();
    await initializeDateFormatting('es_MX');

    final database = AppDatabase();
    final notifications = NotificationService();
    await notifications.init();
    try {
      await SeedData.ensure(database);
    } catch (e) {
      debugPrint('No se pudieron cargar los datos de ejemplo: $e');
    }

    runApp(EscomPerdidosApp(
      database: database,
      secureStore: SecureStore(),
      notifications: notifications,
    ));
  });
}
