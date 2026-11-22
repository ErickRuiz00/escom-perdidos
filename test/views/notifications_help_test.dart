import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/data/models/app_notification.dart';
import 'package:escom_perdidos/data/models/recovery.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/repositories/found_items_repository.dart';
import 'package:escom_perdidos/viewmodels/auth_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/notifications_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/recovery_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:escom_perdidos/views/help/help_center_view.dart';
import 'package:escom_perdidos/views/notifications/notification_preferences_view.dart';
import 'package:escom_perdidos/views/notifications/notifications_view.dart';
import 'package:escom_perdidos/views/recovery/recovery_chat_view.dart';
import 'package:escom_perdidos/views/recovery/recovery_hub_view.dart';
import 'package:escom_perdidos/views/recovery/recovery_request_view.dart';
import 'package:escom_perdidos/views/reports/report_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../notification_helpers.dart';
import '../recovery_helpers.dart';

class _Auth implements AuthRepository {
  @override
  Future<void> cancelPasswordRecovery() async {}
  @override
  Stream<sb.AuthState> get authChanges => const Stream.empty();
  @override
  Future<AppUser?> restoreSession() async => AppUser(
    id: recoveryA,
    name: 'Ana',
    email: 'ana@example.org',
    provider: 'supabase',
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reports implements FoundItemsRepository {
  Report? item;
  @override
  Future<List<Report>> fetchAll() async => item == null ? [] : [item!];
  @override
  Future<List<Report>> fetchMine() async => [];
  @override
  Future<Report?> findById(String id) async => item?.id == id ? item : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  late FakeNotificationsRepository repo;
  late FakeRecoveryRepository recoveryRepo;
  late NotificationsViewModel vm;
  late RecoveryViewModel recovery;
  late AuthViewModel auth;
  late ReportsViewModel reports;
  late _Reports reportsRepo;
  setUp(() async {
    repo = FakeNotificationsRepository(prefs: const NotificationPreferences());
    vm = NotificationsViewModel(repository: repo);
    recoveryRepo = FakeRecoveryRepository()
      ..rows[recoveryId] = recoveryRow(status: 'accepted', version: 2)
      ..chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
    recovery = RecoveryViewModel(repository: recoveryRepo);
    auth = AuthViewModel(_Auth());
    await auth.restoreSession();
    reportsRepo = _Reports();
    reports = ReportsViewModel(repository: reportsRepo);
  });
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    vm.bindUser(recoveryA);
    recovery.bindUser(recoveryA);
    reports.bindUser(recoveryA);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(lazy: false, create: (_) => vm),
          ChangeNotifierProvider(lazy: false, create: (_) => recovery),
          ChangeNotifierProvider(lazy: false, create: (_) => auth),
          ChangeNotifierProvider(lazy: false, create: (_) => reports),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'ayuda accesible y reporte reutiliza solicitudes, oscuro=$dark',
      (tester) async {
        await pump(tester, const HelpCenterView(), dark: dark, scale: 2);
        await tap(tester, 'Prefectura');
        expect(
          find.textContaining('Verifica allí los horarios'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tap(tester, 'Seguridad y abuso');
        expect(find.textContaining('plazo garantizado'), findsOneWidget);
        await tap(tester, 'Ir a mis solicitudes para reportar abuso');
        expect(find.byType(RecoveryHubView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'preferencias guardan categorías y avisan coincidencias futuras',
    (tester) async {
      await pump(tester, const NotificationPreferencesView());
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Mensajes privados'),
      );
      await tester.pumpAndSettle();
      expect(repo.prefs.messages, isFalse);
      expect(repo.saves, 1);
      expect(find.text('Preferencias guardadas'), findsOneWidget);
      expect(
        find.textContaining('cuando las coincidencias estén disponibles'),
        findsOneWidget,
      );
    },
  );
  testWidgets('centro marca leído y abre solicitud con permisos verificados', (
    tester,
  ) async {
    repo.rows = [notification()];
    await pump(tester, const NotificationsView());
    expect(find.text('1 aviso sin leer'), findsOneWidget);
    await tap(tester, 'Aviso 1');
    expect(repo.reads, 1);
    expect(find.byType(RecoveryRequestView), findsOneWidget);
  });
  testWidgets(
    'aviso de mensaje abre chat; el chat cerrado lleva a su solicitud',
    (tester) async {
      repo.rows = [
        notification(
          kind: NotificationKind.privateMessage,
          conversationId: recoveryConversation,
        ),
      ];
      await pump(tester, const NotificationsView());
      await tap(tester, 'Aviso 1');
      expect(find.byType(RecoveryChatView), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      recoveryRepo.chats[0] = RecoveryConversation(
        id: recoveryConversation,
        requestId: recoveryId,
        closedAt: DateTime.utc(2026),
      );
      await tap(tester, 'Aviso 1');
      expect(find.byType(RecoveryRequestView), findsOneWidget);
      expect(find.byType(RecoveryChatView), findsNothing);
    },
  );
  testWidgets(
    'publicación editada abre hallazgo; si no está visible abre solicitud',
    (tester) async {
      reportsRepo.item = Report(
        id: recoveryItem,
        userId: recoveryB,
        type: ReportType.found,
        title: 'Termo azul',
        description: 'Termo de prueba',
        category: ItemCategory.bottles,
        location: 'Biblioteca',
        eventDate: DateTime(2026),
        status: ReportStatus.active,
        custody: ItemCustody.student,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      repo.rows = [notification(kind: NotificationKind.publicationChanged)];
      await pump(tester, const NotificationsView());
      await tap(tester, 'Aviso 1');
      expect(find.byType(ReportDetailView), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      reportsRepo.item = null;
      await tap(tester, 'Aviso 1');
      expect(find.byType(RecoveryRequestView), findsOneWidget);
    },
  );
  testWidgets(
    'destino de solicitud sin permisos conserva aviso y muestra error',
    (tester) async {
      recoveryRepo.rows.clear();
      repo.rows = [notification()];
      await pump(tester, const NotificationsView());
      await tap(tester, 'Aviso 1');
      expect(find.byType(RecoveryRequestView), findsNothing);
      expect(
        find.text('Esta solicitud ya no está disponible para tu cuenta.'),
        findsOneWidget,
      );
      expect(repo.rows.length, 1);
    },
  );
  testWidgets(
    'destino ajeno se rechaza y cambiar sesión oculta la ruta privada',
    (tester) async {
      await pump(
        tester,
        NotificationDestinationView(item: notification(uid: recoveryB)),
      );
      expect(find.text('Este aviso no pertenece a tu cuenta.'), findsOneWidget);
      vm.bindUser(null);
      await tester.pumpAndSettle();
      expect(
        find.text('La sesión cambió. Vuelve a tus avisos.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'centro y preferencias sin conexión ofrecen reintento con texto grande',
    (tester) async {
      repo.fail = true;
      await pump(tester, const NotificationsView(), scale: 2);
      expect(find.text('Sin conexión de prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Preferencias de avisos'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      repo.fail = false;
      await tap(tester, 'Reintentar');
      expect(vm.ready, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
