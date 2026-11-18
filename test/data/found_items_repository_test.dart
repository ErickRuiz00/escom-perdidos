import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/publication_photo.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/report_filter.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/services/media_service.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:escom_perdidos/viewmodels/report_form_viewmodel.dart';
import 'package:escom_perdidos/data/repositories/found_items_repository.dart';
import 'package:escom_perdidos/data/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

const uid = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const id = '11111111-1111-4111-8111-111111111111';
Report fixture({String owner = uid, String identifier = id}) => Report(
  id: identifier,
  userId: owner,
  type: ReportType.found,
  title: 'Termo azul',
  description: 'Termo azul de prueba',
  category: ItemCategory.bottles,
  location: 'Biblioteca',
  eventDate: DateTime(2026, 1, 1),
  status: ReportStatus.active,
  custody: ItemCustody.student,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// HTTP controlado; todas las peticiones pasan por el SDK real. RLS se prueba
/// por separado en PostgreSQL, no se presupone que este doble pruebe el servidor.
class Backend {
  final rows = <String, Map<String, dynamic>>{};
  final photos = <String>{};
  final requests = <http.Request>[];
  bool failWrite = false;
  bool loseInsertReply = false;
  bool failUpload = false;
  int inserts = 0;
  String sessionOwner = uid;
  Future<void> Function()? onNextRead;
  late final sb.SupabaseClient client = sb.SupabaseClient(
    'https://test.supabase.co',
    'sb_publishable_test',
    authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );
  Map<String, dynamic> remote(Report r) => {
    ...r.toRemote(),
    'id': r.id,
    'finder_id': r.userId,
    'status': switch (r.status) {
      ReportStatus.active => 'active',
      ReportStatus.withdrawn => 'withdrawn',
      _ => 'returned',
    },
    'created_at': r.createdAt.toUtc().toIso8601String(),
    'updated_at': r.updatedAt.toUtc().toIso8601String(),
  };
  http.Response json(Object? data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    request: requests.last,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/auth/v1/token') {
      final claims = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': sessionOwner,
                'exp':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');
      return json({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.signature',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': sessionOwner,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.org',
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
    }
    if (path.startsWith('/storage/v1/object/sign/')) {
      return json({
        'signedURL': '/object/sign/found-item-photos/test.png?token=test',
      });
    }
    if (path.startsWith('/storage/v1/object/') && request.method == 'POST') {
      if (failUpload) {
        return json({
          'statusCode': '403',
          'error': 'Unauthorized',
          'message': 'Upload rejected',
        }, 403);
      }
      photos.add(
        path.substring('/storage/v1/object/found-item-photos/'.length),
      );
      return json({'Key': path.substring('/storage/v1/object/'.length)});
    }
    if (path == '/storage/v1/object/found-item-photos' &&
        request.method == 'DELETE') {
      for (final item in (jsonDecode(request.body)['prefixes'] as List)) {
        photos.remove(item);
      }
      return json([]);
    }
    if (path == '/rest/v1/found_items') {
      if (request.method == 'GET' && onNextRead != null) {
        final action = onNextRead!;
        onNextRead = null;
        await action();
      }
      final query = request.url.queryParameters;
      if (request.method == 'POST') {
        inserts++;
        if (failWrite) return json({'code': '42501', 'message': 'denied'}, 403);
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        final row = {
          ...data,
          'finder_id': uid,
          'status': 'active',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        };
        rows[data['id'] as String] = row;
        if (loseInsertReply) {
          throw const SocketException('Controlled response loss');
        }
        return json(row, 201);
      }
      var found = rows.values
          .where((r) => r['status'] == 'active' || r['finder_id'] == uid)
          .toList();
      for (final key in ['id', 'finder_id', 'status', 'updated_at']) {
        final filter = query[key];
        if (filter != null && filter.startsWith('eq.')) {
          found = found
              .where(
                (r) => key == 'updated_at'
                    ? DateTime.parse(
                        r[key] as String,
                      ).isAtSameMomentAs(DateTime.parse(filter.substring(3)))
                    : r[key] == filter.substring(3),
              )
              .toList();
        }
      }
      if (request.method == 'PATCH') {
        if (failWrite) return json({'code': '42501', 'message': 'denied'}, 403);
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        found = found
            .where((r) => r['finder_id'] == uid && r['status'] == 'active')
            .toList();
        for (final row in found) {
          row.addAll(data);
          row['updated_at'] = '2026-01-02T00:00:00Z';
        }
      }
      if (request.headers['accept']?.contains('vnd.pgrst.object') ?? false) {
        return found.isEmpty
            ? json({'code': 'PGRST116', 'message': 'none'}, 406)
            : json(found.single);
      }
      return json(found);
    }
    throw StateError('Unexpected request ${request.method} $path');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Backend backend;
  late FoundItemsRepository repository;
  setUp(() async {
    backend = Backend();
    await backend.client.auth.signInWithPassword(
      email: 'test@example.org',
      password: 'test-password',
    );
    repository = FoundItemsRepository(SupabaseService(client: backend.client));
  });
  tearDown(() => backend.client.dispose());

  test(
    'catálogo consulta active, Mis hallazgos filtra autor y no pide perfiles privados',
    () async {
      backend.rows[id] = backend.remote(fixture());
      backend.rows['22222222-2222-4222-8222-222222222222'] = backend.remote(
        fixture(
          owner: other,
          identifier: '22222222-2222-4222-8222-222222222222',
        ),
      );
      expect(await repository.fetchAll(), hasLength(2));
      expect(await repository.fetchMine(), hasLength(1));
      final reads = backend.requests
          .where((r) => r.url.path.startsWith('/rest/'))
          .toList();
      expect(reads.first.url.queryParameters['status'], 'eq.active');
      expect(reads.last.url.queryParameters['finder_id'], 'eq.$uid');
      expect(
        reads.every(
          (r) =>
              r.url.queryParameters['select'] == FoundItemsRepository.columns,
        ),
        isTrue,
      );
      expect(
        backend.requests.any((r) => r.url.path.contains('profiles')),
        isFalse,
      );
    },
  );

  test(
    'create liga autor a la sesión y no envía fechas ni estado arbitrarios',
    () async {
      final saved = await repository.create(fixture());
      expect(saved.id, id);
      final body =
          jsonDecode(
                backend.requests
                    .singleWhere(
                      (r) =>
                          r.url.path == '/rest/v1/found_items' &&
                          r.method == 'POST',
                    )
                    .body,
              )
              as Map;
      expect(
        body.keys,
        containsAll(['id', 'title', 'category', 'zone', 'custody']),
      );
      expect(body['finder_id'], uid);
      for (final key in [
        'status',
        'created_at',
        'updated_at',
        'contact',
        'boleta',
        'email',
        'phone',
      ]) {
        expect(body.containsKey(key), isFalse);
      }
      await repository.create(fixture());
      expect(
        backend.inserts,
        1,
        reason: 'El UUID estable hace seguro reintentar la misma publicación',
      );
    },
  );

  test(
    'cambiar de cuenta durante la preparación no publica el formulario de otra sesión',
    () async {
      backend.onNextRead = () async {
        backend.sessionOwner = other;
        await backend.client.auth.signInWithPassword(
          email: 'other@example.org',
          password: 'test-password',
        );
      };
      await expectLater(
        repository.create(fixture()),
        throwsA(isA<PermissionException>()),
      );
      expect(backend.inserts, 0);
    },
  );

  test('rechazo del servidor no se convierte en publicación exitosa', () async {
    backend.failWrite = true;
    await expectLater(
      repository.create(fixture()),
      throwsA(isA<PermissionException>()),
    );
    expect(backend.rows, isEmpty);
  });

  test(
    'respuesta perdida se confirma leyendo el mismo UUID sin duplicar',
    () async {
      backend.loseInsertReply = true;
      expect((await repository.create(fixture())).id, id);
      expect(backend.inserts, 1);
      expect(backend.rows, hasLength(1));
    },
  );

  test(
    'rechaza objetos perdidos, autor ajeno y devolución confirmada antes de escribir',
    () async {
      for (final report in [
        fixture().copyWith(type: ReportType.lost),
        fixture(owner: other),
        fixture().copyWith(status: ReportStatus.returned),
      ]) {
        await expectLater(
          repository.create(report),
          throwsA(isA<AppException>()),
        );
      }
      expect(backend.inserts, 0);
    },
  );

  test(
    'update usa versión, permite Prefectura sin confirmar devolución y rechaza reversión',
    () async {
      final original = await repository.create(fixture());
      final saved = await repository.update(
        original.copyWith(custody: ItemCustody.prefecture),
        expectedUpdatedAt: original.updatedAt,
      );
      expect(saved.status, ReportStatus.active);
      expect(saved.custody, ItemCustody.prefecture);
      final patch = backend.requests.lastWhere((r) => r.method == 'PATCH');
      expect(patch.url.queryParameters['updated_at'], isNotNull);
      expect((jsonDecode(patch.body) as Map).containsKey('status'), isFalse);
      await expectLater(
        repository.update(
          saved.copyWith(custody: ItemCustody.student),
          expectedUpdatedAt: saved.updatedAt,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('rechaza edición obsoleta y retirar nunca envía DELETE', () async {
    final original = await repository.create(fixture());
    backend.rows[id]!['updated_at'] = '2026-01-03T00:00:00Z';
    await expectLater(
      repository.update(
        original.copyWith(title: 'Termo cambiado'),
        expectedUpdatedAt: original.updatedAt,
      ),
      throwsA(isA<AppException>()),
    );
    final latest = await repository.findById(id);
    expect((await repository.withdraw(latest!)).status, ReportStatus.withdrawn);
    expect(await repository.fetchAll(), isEmpty);
    expect(await repository.fetchMine(), hasLength(1));
    expect(backend.requests.any((r) => r.method == 'DELETE'), isFalse);
  });

  test(
    'fotografía real validada usa bucket privado, ruta propia y URL temporal',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xff0055a5), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final dir = await Directory.systemTemp.createTemp('found-photo-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/safe.png';
      await File(path).writeAsBytes(data!.buffer.asUint8List());
      final saved = await repository.create(
        fixture().copyWith(photoPath: path),
      );
      expect(saved.photoObjectPath, startsWith('$uid/$id/'));
      expect(saved.photoPath, isNull);
      final url = await repository.signedPhotoUrl(saved.photoObjectPath!);
      expect(url, contains('/object/sign/'));
      final sign = backend.requests.lastWhere(
        (r) => r.url.path.contains('/object/sign/'),
      );
      expect(jsonDecode(sign.body)['expiresIn'], 120);
      final upload = backend.requests.singleWhere(
        (r) =>
            r.url.path.startsWith('/storage/v1/object/found-item-photos/') &&
            r.method == 'POST',
      );
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(
        utf8.decode(upload.bodyBytes, allowMalformed: true).toLowerCase(),
        contains('content-type: image/png'),
      );
      expect(upload.headers['x-upsert'], 'false');
      final cleared = await repository.update(
        saved.copyWith(clearRemotePhoto: true),
        expectedUpdatedAt: saved.updatedAt,
      );
      expect(cleared.photoObjectPath, isNull);
      expect(backend.photos, isEmpty);
      backend.failUpload = true;
      await expectLater(
        repository.create(
          fixture(
            identifier: '22222222-2222-4222-8222-222222222222',
          ).copyWith(photoPath: path),
        ),
        throwsA(isA<StorageException>()),
      );
      expect(backend.rows, hasLength(1));
      backend.failUpload = false;
      backend.failWrite = true;
      await expectLater(
        repository.create(
          fixture(
            identifier: '33333333-3333-4333-8333-333333333333',
          ).copyWith(photoPath: path),
        ),
        throwsA(isA<PermissionException>()),
      );
      expect(
        backend.photos,
        isEmpty,
        reason:
            'El archivo provisional se limpia si el servidor rechazó el INSERT',
      );
    },
  );

  test('validación rechaza SVG, GIF, archivos vacíos y exceso de tamaño', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList(utf8.encode('<svg/>')),
      Uint8List.fromList(utf8.encode('GIF89a')),
      Uint8List(PublicationPhoto.maxBytes + 1),
    ]) {
      expect(
        () => PublicationPhoto.inspect(bytes),
        throwsA(isA<AppException>()),
      );
    }
  });
  test('filtro de fechas incluye ambos extremos y limpiar los elimina', () {
    final r = fixture();
    final filter = ReportFilter(
      foundFrom: DateTime(2026, 1, 1),
      foundTo: DateTime(2026, 1, 1),
    );
    expect(filter.apply([r]), hasLength(1));
    expect(
      filter.copyWith(foundFrom: () => DateTime(2026, 1, 2)).apply([r]),
      isEmpty,
    );
    expect(filter.clearFilters().activeCount, 0);
  });

  test(
    'una respuesta tardía de la cuenta anterior no rellena el catálogo de otra sesión',
    () async {
      final source = SlowRepository();
      final vm = ReportsViewModel(repository: source);
      addTearDown(vm.dispose);
      vm.bindUser(uid);
      await Future<void>.delayed(Duration.zero);
      vm.bindUser(other);
      await Future<void>.delayed(Duration.zero);
      source.pendingLoad.complete([fixture()]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.communityFound, isEmpty);
      expect(vm.byId(id), isNull);
      expect(vm.mine(uid), isEmpty);
    },
  );

  test(
    'formulario bloquea doble envío y conserva UUID durante la confirmación',
    () async {
      final source = SlowRepository();
      source.pendingLoad.complete([]);
      final vm = ReportsViewModel(repository: source);
      vm.bindUser(uid);
      await Future<void>.delayed(Duration.zero);
      final form = ReportFormViewModel(
        reports: vm,
        media: MediaService(),
        author: AppUser(
          id: uid,
          name: 'Ana',
          email: 'test@example.org',
          provider: 'supabase',
          createdAt: DateTime(2026),
        ),
      );
      addTearDown(form.dispose);
      addTearDown(vm.dispose);
      final first = form.save(
        title: 'Termo azul',
        description: 'Termo azul de prueba',
      );
      expect(
        await form.save(
          title: 'Termo azul',
          description: 'Termo azul de prueba',
        ),
        contains('Espera'),
      );
      expect(source.creates, 1);
      source.pendingSave.complete(source.sent!);
      expect(await first, isNull);
      expect(form.savedReport!.id, source.sent!.id);
      expect(vm.communityFound.single.id, source.sent!.id);
    },
  );
}

class SlowRepository implements FoundItemsRepository {
  final pendingLoad = Completer<List<Report>>();
  final pendingSave = Completer<Report>();
  int reads = 0;
  int creates = 0;
  Report? sent;
  @override
  Future<List<Report>> fetchAll() =>
      reads++ == 0 ? pendingLoad.future : Future.value([]);
  @override
  Future<List<Report>> fetchMine() async => [];
  @override
  Future<Report> create(Report report) {
    creates++;
    sent = report;
    return pendingSave.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
