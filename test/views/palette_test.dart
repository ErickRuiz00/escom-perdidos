import 'dart:math' as math;

import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/theme/app_status_colors.dart';
import 'package:escom_perdidos/core/theme/app_theme.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/features/splash/presentation/animated_circuit_logo.dart';
import 'package:escom_perdidos/features/splash/presentation/splash_progress_bar.dart';
import 'package:escom_perdidos/features/splash/presentation/splash_screen.dart';
import 'package:escom_perdidos/views/widgets/common.dart';
import 'package:escom_perdidos/views/widgets/report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  for (final dark in [false, true]) {
    final label = dark ? 'oscuro' : 'claro';
    final theme = dark ? AppTheme.dark() : AppTheme.light();

    test('contraste de texto y estados en modo $label', () {
      final scheme = theme.colorScheme;
      final status = theme.extension<AppStatusColors>()!;
      final pairs = [
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        for (final state in ItemVisualState.values)
          (
            status.forState(state).foreground,
            status.forState(state).background,
          ),
      ];
      for (final (foreground, background) in pairs) {
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    });

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets(
        'splash centrada desde el primer frame: $width, modo $label',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(theme: theme, home: const SplashScreen()),
          );
          await tester.pump();
          void checkCenter() {
            for (final finder in [
              find.byType(AnimatedCircuitLogo),
              find.text('Encuéntralo ESCOM'),
              find.byType(SplashProgressBar),
              find.text('COMUNIDAD ESTUDIANTIL ESCOM'),
            ]) {
              expect(tester.getCenter(finder).dx, closeTo(width / 2, 0.5));
            }
            expect(tester.takeException(), isNull);
          }

          checkCenter();
          await tester.pump(const Duration(milliseconds: 1900));
          checkCenter();
          await tester.pump(SplashScreen.duration);
          checkCenter();
        },
      );
    }

    testWidgets('tarjeta con ubicación y estado: texto grande, modo $label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2026);
      final report = Report(
        id: 'preview',
        userId: 'student',
        type: ReportType.found,
        title: 'Computadora portátil',
        description: 'Reporte de prueba',
        category: ItemCategory.electronics,
        location: 'Laboratorios de cómputo',
        eventDate: date,
        status: ReportStatus.resolved,
        createdAt: date,
        updatedAt: date,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ReportList(reports: [report], onTap: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LocationTag), findsOneWidget);
      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('Encontrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
