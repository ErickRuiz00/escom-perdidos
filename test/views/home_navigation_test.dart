import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/app_notification.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/repositories/found_items_repository.dart';
import 'package:escom_perdidos/data/services/location_service.dart';
import 'package:escom_perdidos/data/services/media_service.dart';
import 'package:escom_perdidos/data/services/notification_service.dart';
import 'package:escom_perdidos/viewmodels/auth_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/profile_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/recovery_viewmodel.dart';
import '../recovery_helpers.dart';
import '../notification_helpers.dart';
import 'package:escom_perdidos/viewmodels/notifications_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/tutorial_viewmodel.dart';
import 'package:escom_perdidos/views/auth/auth_flow.dart';
import 'package:escom_perdidos/views/auth/welcome_view.dart';
import 'package:escom_perdidos/views/home/home_shell.dart';
import 'package:escom_perdidos/views/home/explore_view.dart';
import 'package:escom_perdidos/views/reports/report_form_view.dart';
import 'package:escom_perdidos/views/widgets/report_card.dart';
import 'package:escom_perdidos/views/widgets/common.dart';
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

class _Reports implements FoundItemsRepository {
  final items = <Report>[];
  bool rejectWrite = false;
  @override
  Future<List<Report>> fetchAll() async =>
      items.where((r) => r.isActive).toList();
  @override
  Future<List<Report>> fetchMine() async =>
      items.where((r) => r.userId == _user.id).toList();
  @override
  Future<Report?> findById(String id) async {
    for (final r in items) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<Report> create(Report report) async {
    if (rejectWrite) throw const FormatException('Fallo de prueba');
    items.add(report);
    return report;
  }

  @override
  Future<Report> withdraw(Report report) async {
    final saved = report.copyWith(status: ReportStatus.withdrawn);
    items[items.indexWhere((r) => r.id == report.id)] = saved;
    return saved;
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
  late RecoveryViewModel recovery;
  late NotificationsViewModel inbox;
  late FakeNotificationsRepository inboxRepository;
  late TutorialViewModel tutorial;
  final media = MediaService();
  final notifications = NotificationService();
  setUp(() async {
    final authRepository = _Auth();
    auth = AuthViewModel(authRepository);
    await auth.restoreSession();
    repository = _Reports();
    reports = ReportsViewModel(repository: repository);
    recovery = RecoveryViewModel(
      repository: FakeRecoveryRepository(uid: _user.id),
    );
    inboxRepository = FakeNotificationsRepository(uid: _user.id);
    inbox = NotificationsViewModel(repository: inboxRepository);
    tutorial = TutorialViewModel()..bindUser(_user.id);
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
    recovery.bindUser(_user.id);
    inbox.bindUser(_user.id);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: reports),
          ChangeNotifierProvider(create: (_) => recovery),
          ChangeNotifierProvider(create: (_) => inbox),
          ChangeNotifierProvider(lazy: false, create: (_) => tutorial),
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

  Future<void> tourButton(WidgetTester tester, String text) async {
    final button = find.descendant(
      of: find.byKey(const Key('section-tutorial-overlay')),
      matching: find.text(text),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 640), const Size(840, 500)]) {
      testWidgets(
        'recorrido señala las cinco secciones reales: $size, oscuro=$dark, texto 200%',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await pump(tester, dark: dark, scale: 2);
          tutorial.start();
          await tester.pumpAndSettle();
          for (var step = 0; step < 5; step++) {
            final title = [
              'Inicio',
              'Explorar',
              'Publicar',
              'Chats',
              'Perfil',
            ][step];
            expect(
              tester
                  .widget<Text>(find.byKey(const Key('tutorial-section-title')))
                  .data,
              title,
            );
            expect(find.byKey(const Key('tutorial-arrow')), findsOneWidget);
            final highlight = tester.getRect(
              find.byKey(const Key('tutorial-spotlight')),
            );
            if (size.width >= 700) {
              final rail = find.byType(NavigationRail);
              expect(tester.widget<NavigationRail>(rail).selectedIndex, step);
              expect(tester.getRect(rail).contains(highlight.center), isTrue);
            } else {
              final nav = find.byType(NavigationBar);
              expect(tester.widget<NavigationBar>(nav).selectedIndex, step);
              final bounds = tester.getRect(nav);
              expect(
                highlight.center.dx,
                closeTo(bounds.left + bounds.width * (step + 0.5) / 5, 1),
              );
              expect(bounds.contains(highlight.center), isTrue);
            }
            expect(find.text('Así es. Ya puedes continuar.'), findsNothing);
            expect(tester.takeException(), isNull);
            if (step == 1) {
              await tourButton(tester, 'Anterior');
              expect(tutorial.step, 0);
              await tourButton(tester, 'Siguiente');
            }
            await tourButton(tester, step == 4 ? 'Terminar' : 'Siguiente');
          }
          expect(
            find.byKey(const Key('section-tutorial-overlay')),
            findsNothing,
          );
          expect(inboxRepository.tutorials, 1);
          expect(tutorial.active, isFalse);
        },
      );
    }
  }

  testWidgets(
    'invitación inicia recorrido, tocar foco avanza y se puede omitir y repetir desde ayuda',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      inboxRepository.prefs = const NotificationPreferences();
      await pump(tester);
      await tester.tap(find.text('Ver tutorial'));
      await tester.pumpAndSettle();
      expect(tutorial.active, isTrue);
      await tester.tapAt(const Offset(380, 12));
      await tester.pumpAndSettle();
      expect(tutorial.step, 0);
      await tester.tap(find.byKey(const Key('tutorial-spotlight')));
      await tester.pumpAndSettle();
      expect(tutorial.step, 1);
      await tourButton(tester, 'Omitir');
      expect(inboxRepository.prefs.tutorialVersion, 1);
      await tab(tester, 'Perfil');
      await tester.ensureVisible(find.text('Ver tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver tutorial'));
      await tester.pumpAndSettle();
      expect(tutorial.step, 0);
      await tourButton(tester, 'Omitir');
      await tab(tester, 'Perfil');
      await tester.ensureVisible(find.text('Centro de ayuda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Centro de ayuda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver tutorial'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(tutorial.active, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tutorial.active, isFalse);
      expect(inboxRepository.tutorials, 3);
    },
  );

  testWidgets(
    'el foco se adapta al girar la pantalla y respeta las áreas del sistema',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await pump(tester);
      tutorial.start();
      tutorial.goTo(4);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('tutorial-spotlight'))).bottom,
        lessThan(820),
      );
      tester.view.physicalSize = const Size(840, 500);
      await tester.pumpAndSettle();
      expect(tutorial.step, 4);
      expect(
        tester
            .getRect(find.byType(NavigationRail))
            .contains(
              tester.getCenter(find.byKey(const Key('tutorial-spotlight'))),
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tourButton(tester, 'Terminar');
    },
  );

  testWidgets(
    'omitir funciona sin conexión y cambiar de cuenta limpia el recorrido',
    (tester) async {
      await pump(tester);
      tutorial.start();
      await tester.pumpAndSettle();
      inboxRepository.fail = true;
      await tourButton(tester, 'Omitir');
      expect(tutorial.active, isFalse);
      expect(inboxRepository.tutorials, 0);
      expect(find.textContaining('Cerraste la guía.'), findsOneWidget);
      tutorial.start();
      await tester.pumpAndSettle();
      tutorial.bindUser(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('section-tutorial-overlay')), findsNothing);
    },
  );

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
      expect(find.text('Sin conversaciones por ahora'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'publicación confirmada muestra logo y aparece en catálogo y Mis hallazgos',
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
      expect(
        find.textContaining('tus datos de perfil permanecen privados'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Termo azul');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Termo azul encontrado sin nombre',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Publicar hallazgo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Publicar hallazgo'));
      await tester.pumpAndSettle();
      expect(find.text('Hallazgo publicado'), findsOneWidget);
      expect(find.byType(BrandDialogLogo), findsOneWidget);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportFormView), findsNothing);
      expect(repository.items.last.title, 'Termo azul');
      expect(repository.items.last.type, ReportType.found);
      expect(repository.items.last.custody, ItemCustody.student);
      expect(reports.communityFound.single.title, 'Termo azul');
      await tab(tester, 'Inicio');
      expect(find.byType(ReportCard), findsOneWidget);
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
    'retiro propio usa confirmación con logo y desaparece del catálogo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2026);
      repository.items.add(
        Report(
          id: 'remote-item',
          userId: _user.id,
          type: ReportType.found,
          title: 'Termo real de prueba',
          description: 'Termo de prueba para retiro',
          category: ItemCategory.bottles,
          location: 'Biblioteca',
          eventDate: date,
          status: ReportStatus.active,
          custody: ItemCustody.student,
          createdAt: date,
          updatedAt: date,
        ),
      );
      await pump(tester);
      await tester.ensureVisible(find.byType(ReportCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReportCard));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retirar publicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar publicación'));
      await tester.pumpAndSettle();
      expect(find.byType(BrandDialogLogo), findsOneWidget);
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      expect(find.text('Retirada'), findsOneWidget);
      expect(find.text('Editar publicación'), findsNothing);
      expect(find.text('Retirar publicación'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReportCard), findsNothing);
      expect(reports.communityFound, isEmpty);
      expect(reports.mine(_user.id).single.status, ReportStatus.withdrawn);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detalle ajeno con custodia Alumno activa la solicitud privada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime(2026);
    repository.items.add(
      Report(
        id: 'student-item',
        userId: 'other-student',
        type: ReportType.found,
        title: 'Llaves de prueba',
        description: 'Llaves con llavero de prueba',
        category: ItemCategory.keys,
        location: 'Biblioteca',
        eventDate: date,
        status: ReportStatus.active,
        custody: ItemCustody.student,
        createdAt: date,
        updatedAt: date,
      ),
    );
    await pump(tester);
    await tester.ensureVisible(find.byType(ReportCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReportCard));
    await tester.pumpAndSettle();
    final claim = find.widgetWithText(FilledButton, 'Creo que es mío');
    expect(claim, findsOneWidget);
    expect(tester.widget<FilledButton>(claim).onPressed, isNotNull);
    await tester.ensureVisible(claim);
    await tester.tap(claim);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-evidence')), findsOneWidget);
    expect(find.text('Editar publicación'), findsNothing);
    expect(find.text('Retirar publicación'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detalle ajeno en Prefectura declara entrega sin ofrecer edición ni confirmarla',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2026);
      repository.items.add(
        Report(
          id: 'someone-elses-item',
          userId: 'other-student',
          type: ReportType.found,
          title: 'Llaves de prueba',
          description: 'Llaves con llavero de prueba',
          category: ItemCategory.keys,
          location: 'Biblioteca',
          eventDate: date,
          status: ReportStatus.active,
          custody: ItemCustody.prefecture,
          createdAt: date,
          updatedAt: date,
        ),
      );
      await pump(tester);
      await tester.ensureVisible(find.byType(ReportCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReportCard));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Prefectura no ha confirmado su recepción'),
        findsOneWidget,
      );
      expect(find.text('Editar publicación'), findsNothing);
      expect(find.text('Retirar publicación'), findsNothing);
      expect(find.text('Creo que es mío'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un error al publicar conserva formulario y no muestra confirmación de éxito',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.rejectWrite = true;
      await pump(tester);
      await tab(tester, 'Publicar');
      await tester.ensureVisible(find.text('Preparar hallazgo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preparar hallazgo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Termo azul');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Termo azul encontrado',
      );
      final submit = find.widgetWithText(FilledButton, 'Publicar hallazgo');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(ReportFormView), findsOneWidget);
      expect(find.text('Hallazgo publicado'), findsNothing);
      expect(repository.items, isEmpty);
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
