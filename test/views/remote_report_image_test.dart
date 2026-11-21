import 'dart:async';
import 'dart:io';

import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/repositories/found_items_repository.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:escom_perdidos/views/widgets/remote_report_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Photos implements FoundItemsRepository {
  final pending = <Completer<String>>[];
  @override
  Future<List<Report>> fetchAll() async => [];
  @override
  Future<List<Report>> fetchMine() async => [];
  @override
  Future<String> signedPhotoUrl(String path) {
    final request = Completer<String>();
    pending.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mantiene la descarga en espera para probar el cambio de autorización sin
// acceder a la red ni provocar el HTTP 400 del cliente predeterminado de tests.
class _PendingHttp implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final changeAccount in [false, true]) {
    testWidgets(
      'foto anterior desaparece mientras se autoriza ${changeAccount ? 'otra cuenta' : 'otra ruta'}',
      (tester) async {
        debugNetworkImageHttpClientProvider = () => _PendingHttp();
        try {
          final source = _Photos();
          final reports = ReportsViewModel(repository: source)..bindUser('A');
          addTearDown(reports.dispose);
          Future<void> show(String path) => tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: reports,
              child: MaterialApp(
                home: SizedBox(
                  width: 100,
                  height: 100,
                  child: RemoteReportImage(
                    storagePath: path,
                    placeholder: const ColoredBox(color: Colors.grey),
                  ),
                ),
              ),
            ),
          );

          await show('A/photo.png');
          source.pending.single.complete('https://test.invalid/photo-a');
          await tester.pump();
          await tester.pump();
          expect(find.byType(Image), findsOneWidget);
          final oldImage = tester.widget<Image>(find.byType(Image)).image;
          expect(
            (await oldImage.obtainCacheStatus(
              configuration: ImageConfiguration.empty,
            ))!.pending,
            isTrue,
          );

          if (changeAccount) {
            reports.bindUser('B');
            await tester.pump();
          } else {
            await show('A/another-photo.png');
          }
          await tester.pump();
          expect(source.pending, hasLength(2));
          expect(find.byType(Image), findsNothing);
          expect(
            (await oldImage.obtainCacheStatus(
              configuration: ImageConfiguration.empty,
            ))!.pending,
            isFalse,
          );
          expect(tester.takeException(), isNull);

          // Se desmonta antes de resolver la segunda URL: una respuesta tardía
          // tampoco debe reconstruir una imagen de una pantalla ya cerrada.
          await tester.pumpWidget(const SizedBox());
          source.pending.last.complete('https://test.invalid/photo-b');
          await tester.pump();
          expect(find.byType(Image), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugNetworkImageHttpClientProvider = null;
        }
      },
    );
  }

  testWidgets('fallo de descarga reautoriza una vez sin errores de setState', (
    tester,
  ) async {
    final source = _Photos();
    final reports = ReportsViewModel(repository: source)..bindUser('A');
    addTearDown(reports.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: reports,
        child: const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: RemoteReportImage(
              storagePath: 'A/photo.png',
              placeholder: ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
    // El HttpClient de flutter_test devuelve 400 sin acceder a la red.
    source.pending.single.complete('https://test.invalid/failing-photo');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(source.pending, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    source.pending.last.complete('https://test.invalid/retry-photo');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
