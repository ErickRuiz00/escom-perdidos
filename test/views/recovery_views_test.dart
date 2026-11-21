import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/recovery.dart';
import 'package:escom_perdidos/viewmodels/recovery_viewmodel.dart';
import 'package:escom_perdidos/views/recovery/recovery_request_form.dart';
import 'package:escom_perdidos/views/recovery/recovery_request_view.dart';
import 'package:escom_perdidos/views/recovery/recovery_chat_view.dart';
import 'package:escom_perdidos/views/recovery/recovery_hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../recovery_helpers.dart';

final _found = Report(
  id: recoveryItem,
  userId: recoveryA,
  type: ReportType.found,
  title: 'Termo azul',
  description: 'Termo azul de prueba',
  category: ItemCategory.bottles,
  location: 'Biblioteca',
  eventDate: DateTime(2026, 11, 20),
  status: ReportStatus.active,
  custody: ItemCustody.student,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Future<void> _pump(
  WidgetTester tester,
  FakeRecoveryRepository repository,
  Widget page, {
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) =>
          RecoveryViewModel(repository: repository)..bindUser(repository.uid),
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
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  testWidgets(
    'B envía evidencia privada tras validar y confirmar; abre su solicitud',
    (tester) async {
      final source = FakeRecoveryRepository(uid: recoveryB);
      await _pump(tester, source, RecoveryRequestForm(report: _found));
      await tester.enterText(
        find.byKey(const Key('recovery-evidence')),
        'corta',
      );
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe al menos 20 caracteres.'), findsOneWidget);
      expect(source.creates, 0);
      await tester.enterText(
        find.byKey(const Key('recovery-evidence')),
        'Marca privada dentro de la tapa del termo',
      );
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar solicitud privada?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enviar solicitud').last,
      );
      await tester.pumpAndSettle();
      expect(source.creates, 1);
      expect(find.byType(RecoveryRequestView), findsOneWidget);
      expect(find.text('Características privadas'), findsOneWidget);
      expect(find.text('Aceptar solicitud'), findsNothing);
    },
  );
  testWidgets(
    'A revisa evidencia, acepta y abre solo el chat de esa solicitud',
    (tester) async {
      final source = FakeRecoveryRepository()..rows[recoveryId] = recoveryRow();
      await _pump(
        tester,
        source,
        const RecoveryRequestView(requestId: recoveryId),
      );
      expect(find.text('Abrir chat privado'), findsNothing);
      await tester.ensureVisible(find.text('Aceptar solicitud'));
      await tester.tap(find.text('Aceptar solicitud'));
      await tester.pumpAndSettle();
      expect(find.text('¿Aceptar solicitud?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir chat privado'), findsOneWidget);
      await tester.ensureVisible(find.text('Abrir chat privado'));
      await tester.tap(find.text('Abrir chat privado'));
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryChatView), findsOneWidget);
      expect(find.byKey(const Key('recovery-message')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recovery-message')),
        '¿Puedes describir la marca?',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(find.text('¿Puedes describir la marca?'), findsOneWidget);
      expect(source.sent, hasLength(1));
    },
  );
  testWidgets(
    'B no ve acciones del encontrador y confirma recepción con diálogo explícito',
    (tester) async {
      final source = FakeRecoveryRepository(uid: recoveryB)
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      await _pump(
        tester,
        source,
        const RecoveryRequestView(requestId: recoveryId),
      );
      expect(find.text('Aceptar solicitud'), findsNothing);
      expect(find.text('Rechazar solicitud'), findsNothing);
      await tester.ensureVisible(find.text('Confirmar que recibí'));
      await tester.tap(find.text('Confirmar que recibí'));
      await tester.pumpAndSettle();
      expect(source.rows[recoveryId]!['requester_confirmed_at'], isNull);
      expect(find.text('¿Ya recibiste el objeto?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar recepción'),
      );
      await tester.pumpAndSettle();
      expect(source.rows[recoveryId]!['requester_confirmed_at'], isNotNull);
      expect(source.rows[recoveryId]!['status'], 'accepted');
      expect(
        find.text(
          'Tu confirmación está registrada. Esperamos a la otra parte.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'cambio a C oculta evidencia y chat de A/B incluso en ruta abierta',
    (tester) async {
      final source = FakeRecoveryRepository(uid: recoveryB)
        ..rows[recoveryId] = recoveryRow(status: 'accepted');
      source.chats.add(
        const RecoveryConversation(
          id: recoveryConversation,
          requestId: recoveryId,
        ),
      );
      source.sent.add(
        RecoveryMessage(
          id: 'private',
          conversationId: recoveryConversation,
          senderId: recoveryA,
          body: 'Dato secreto de A y B',
          createdAt: DateTime(2026),
        ),
      );
      await _pump(
        tester,
        source,
        const RecoveryChatView(
          conversation: RecoveryConversation(
            id: recoveryConversation,
            requestId: recoveryId,
          ),
        ),
      );
      expect(find.text('Dato secreto de A y B'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recovery-message')),
        'Borrador privado de B',
      );
      final draft = tester
          .widget<TextField>(find.byKey(const Key('recovery-message')))
          .controller!;
      final root = tester
          .element(find.byType(RecoveryChatView))
          .read<RecoveryViewModel>();
      source.uid = recoveryC;
      source.chats.clear();
      root.bindUser(recoveryC);
      await tester.pumpAndSettle();
      expect(find.text('Dato secreto de A y B'), findsNothing);
      expect(find.byKey(const Key('recovery-message')), findsNothing);
      expect(find.text('Conversación cerrada'), findsOneWidget);
      expect(draft.text, isEmpty);
    },
  );
  testWidgets(
    'cambiar de cuenta elimina el borrador privado de una solicitud',
    (tester) async {
      final source = FakeRecoveryRepository(uid: recoveryB);
      await _pump(tester, source, RecoveryRequestForm(report: _found));
      await tester.enterText(
        find.byKey(const Key('recovery-evidence')),
        'Evidencia privada de la sesión B',
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('recovery-evidence')),
      );
      final root = tester
          .element(find.byType(RecoveryRequestForm))
          .read<RecoveryViewModel>();
      source.uid = recoveryC;
      root.bindUser(recoveryC);
      await tester.pumpAndSettle();
      expect(field.controller!.text, isEmpty);
      expect(find.byKey(const Key('recovery-evidence')), findsNothing);
      expect(source.creates, 0);
    },
  );
  for (final dark in [false, true]) {
    for (final unavailable in ['form', 'request']) {
      testWidgets(
        '$unavailable no disponible admite texto 200%, oscuro=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final source = FakeRecoveryRepository(uid: recoveryA);
          await _pump(
            tester,
            source,
            unavailable == 'form'
                ? RecoveryRequestForm(report: _found)
                : const RecoveryRequestView(requestId: recoveryId),
            dark: dark,
            scale: 2,
          );
          expect(find.text('Solicitud no disponible'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(source.creates, 0);
        },
      );
    }
    for (final screen in ['form', 'request', 'chat', 'hub']) {
      testWidgets('$screen sin overflow en 320 px y texto 200%, oscuro=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = FakeRecoveryRepository(uid: recoveryB)
          ..rows[recoveryId] = recoveryRow(status: 'accepted');
        source.chats.add(
          const RecoveryConversation(
            id: recoveryConversation,
            requestId: recoveryId,
          ),
        );
        final Widget view = switch (screen) {
          'form' => RecoveryRequestForm(report: _found),
          'request' => const RecoveryRequestView(requestId: recoveryId),
          'chat' => const RecoveryChatView(
            conversation: RecoveryConversation(
              id: recoveryConversation,
              requestId: recoveryId,
            ),
          ),
          _ => const RecoveryHubView(),
        };
        await _pump(tester, source, view, dark: dark, scale: 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
