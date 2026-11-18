import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/repositories/report_repository.dart';
import 'package:escom_perdidos/data/services/location_service.dart';
import 'package:escom_perdidos/data/services/media_service.dart';
import 'package:escom_perdidos/data/services/notification_service.dart';
import 'package:escom_perdidos/viewmodels/auth_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/profile_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:escom_perdidos/views/auth/auth_flow.dart';
import 'package:escom_perdidos/views/auth/welcome_view.dart';
import 'package:escom_perdidos/views/home/home_shell.dart';
import 'package:escom_perdidos/views/home/explore_view.dart';
import 'package:escom_perdidos/views/reports/report_form_view.dart';
import 'package:escom_perdidos/views/widgets/report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final _user = AppUser(
  id: 'remote-user',
  name: 'Ana López',
  email: 'ana@example.org',
  provider: 'supabase',
  createdAt: DateTime(2026),
);

class _Auth implements AuthRepository {
  @override
  Future<void> cancelPasswordRecovery() async {}
  @override
  Stream<sb.AuthState> get authChanges => const Stream.empty();
  @override
  Future<AppUser?> restoreSession() async => _user;
  @override
  Future<void> logout() async {}
  @override
  Future<AppUser> updateProfile(AppUser user) async => user;
  @override
  bool get googleAvailable => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reports implements ReportRepository {
  final items = <Report>[
    Report(
      id: 'legacy',
      userId: 'sample-author',
      type: ReportType.found,
      title: 'Muestra que nunca debe ser pública',
      description: 'Muestra antigua',
      category: ItemCategory.electronics,
      location: 'Biblioteca',
      eventDate: DateTime(2026),
      status: ReportStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  Future<List<Report>> fetchAll() async => List.of(items);
  @override
  Future<void> create(Report report) async {
    items.add(report);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  late AuthViewModel auth;
  late ReportsViewModel reports;
  late ProfileViewModel profile;
  late _Reports repository;
  final media = MediaService();
  final notifications = NotificationService();
  setUp(() async {
    final authRepository = _Auth();
    auth = AuthViewModel(authRepository);
    await auth.restoreSession();
    repository = _Reports();
    reports = ReportsViewModel(
      repository: repository,
      notifications: notifications,
      media: media,
    );
    profile = ProfileViewModel(
      repository: authRepository,
      auth: auth,
      media: media,
      notifications: notifications,
    );
  });
  tearDown(() {
    profile.dispose();
    reports.dispose();
    auth.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    bool gate = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: reports),
          ChangeNotifierProvider.value(value: profile),
          Provider.value(value: media),
          Provider(create: (_) => LocationService()),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('es', 'MX'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'MX')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: gate ? const AuthGate() : const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    final destination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    await tester.tap(destination);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cinco pestañas conservan consulta, filtros, scroll y subpestaña de chats',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.byType(ReportCard), findsNothing);
      expect(find.textContaining('Muestra que'), findsNothing);
      await tester.enterText(find.byKey(const Key('home-search')), 'termo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreView), findsOneWidget);
      expect(find.text('termo'), findsOneWidget);
      await tester.ensureVisible(find.text('Llaves'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Llaves'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('explore-scroll')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('explore-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      await tab(tester, 'Chats');
      await tester.tap(find.text('Conversaciones'));
      await tester.pumpAndSettle();
      await tab(tester, 'Perfil');
      expect(find.text('Ana López'), findsOneWidget);
      await tab(tester, 'Explorar');
      expect(find.text('termo'), findsOneWidget);
      expect(find.text('Filtros (1)'), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const PageStorageKey('explore-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .pixels,
        scroll,
      );
      await tab(tester, 'Chats');
      expect(find.text('Un espacio para reencontrarse'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'formulario guarda solo un hallazgo local y no lo mezcla con el catálogo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
      await tab(tester, 'Publicar');
      await tester.ensureVisible(find.text('Preparar hallazgo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preparar hallazgo'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportFormView), findsOneWidget);
      expect(find.text('Perdido'), findsNothing);
      expect(find.textContaining('solo en este dispositivo'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Termo azul');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Termo azul encontrado sin nombre',
      );
      await tester.ensureVisible(
        find.text('Guardar hallazgo en este dispositivo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar hallazgo en este dispositivo'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportFormView), findsNothing);
      expect(repository.items.last.title, 'Termo azul');
      expect(repository.items.last.type, ReportType.found);
      expect(repository.items.last.custody, ItemCustody.student);
      expect(reports.communityFound, isEmpty);
      await tab(tester, 'Inicio');
      expect(find.byType(ReportCard), findsNothing);
      await tab(tester, 'Perfil');
      await tester.ensureVisible(find.text('Mis hallazgos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis hallazgos'));
      await tester.pumpAndSettle();
      expect(find.text('Termo azul'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'campana abre centro vacío; logout elimina rutas privadas desde AuthGate',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, gate: true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Centro de notificaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Tu centro de notificaciones'), findsOneWidget);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.byType(HomeShell, skipOffstage: false), findsNothing);
      expect(
        find.text('Tu centro de notificaciones', skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets('accesos de Perfil y configuración admiten texto grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, scale: 2);
    await tab(tester, 'Perfil');
    for (final label in [
      'Mis hallazgos',
      'Mis búsquedas',
      'Mis hazañas',
      'Configuración',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (label == 'Configuración') {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(auth.user!.darkMode, isTrue);
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 640), const Size(840, 500)]) {
      testWidgets(
        'todas las secciones sin overflow: $size, oscuro=$dark, texto 200%',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await pump(tester, dark: dark, scale: 2);
          expect(tester.takeException(), isNull);
          for (final label in [
            'Explorar',
            'Publicar',
            'Chats',
            'Perfil',
            'Inicio',
          ]) {
            final nav = find.byType(
              size.width >= 700 ? NavigationRail : NavigationBar,
            );
            final labelFinder = find.descendant(
              of: nav,
              matching: find.text(label),
            );
            await tester.ensureVisible(labelFinder);
            await tester.tap(labelFinder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
