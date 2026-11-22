import 'dart:convert';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/app_notification.dart';
import 'package:escom_perdidos/data/repositories/notifications_repository.dart';
import 'package:escom_perdidos/data/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../notification_helpers.dart';
import '../recovery_helpers.dart';

class _Api {
  String uid = recoveryA;
  String? error;
  bool noPreferences = false;
  Future<void> Function()? beforeReply;
  final requests = <http.Request>[];
  late final client = sb.SupabaseClient(
    'https://test.supabase.co',
    'sb_publishable_test',
    authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );
  final prefs = <String, dynamic>{
    'user_id': recoveryA,
    'recovery_requests': true,
    'private_messages': true,
    'status_returns': true,
    'matches': true,
    'tutorial_version': 0,
  };
  Future<void> login(String id) async {
    uid = id;
    await client.auth.signInWithPassword(
      email: 'test@example.org',
      password: 'test-password',
    );
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    http.Response json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    if (request.url.path == '/auth/v1/token') {
      final claims = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'sub': uid,
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
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.org',
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
    }
    if (error != null) {
      return json({'code': error, 'message': 'PRIVATE SERVER DETAILS'}, 400);
    }
    final callback = beforeReply;
    beforeReply = null;
    await callback?.call();
    if (request.url.path.endsWith('/notifications')) {
      if (request.method == 'HEAD') {
        return http.Response(
          '',
          200,
          headers: {'content-range': '*/73'},
          request: request,
        );
      }
      return json([
        {
          'id': notification().id,
          'recipient_id': recoveryA,
          'kind': 'recovery_request',
          'title': 'Nueva solicitud',
          'body': 'Consulta tu solicitud.',
          'item_id': recoveryItem,
          'request_id': recoveryId,
          'conversation_id': null,
          'created_at': '2026-11-21T00:00:01Z',
          'alert_enabled': true,
          'read_at': null,
        },
      ]);
    }
    if (request.url.path.endsWith('/notification_preferences')) {
      return json(noPreferences ? [] : [prefs]);
    }
    if (request.url.path.endsWith(
      '/encuentralo_save_notification_preferences',
    )) {
      final body = jsonDecode(request.body) as Map;
      prefs.addAll({
        'recovery_requests': body['p_requests'],
        'private_messages': body['p_messages'],
        'status_returns': body['p_status'],
        'matches': body['p_matches'],
      });
      return json(prefs);
    }
    return json(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late NotificationsRepository repo;
  setUp(() async {
    api = _Api();
    await api.login(recoveryA);
    repo = NotificationsRepository(SupabaseService(client: api.client));
  });
  tearDown(() async {
    await api.client.dispose();
  });
  test(
    'consulta SDK real filtra destinatario y pagina por fecha e UUID',
    () async {
      final page = await repo.page();
      expect(page.single.requestId, recoveryId);
      var query = api.requests.last.url.queryParameters;
      expect(query['recipient_id'], 'eq.$recoveryA');
      expect(query['limit'], '50');
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      await repo.page(before: page.single);
      query = api.requests.last.url.queryParameters;
      expect(query['or'], contains('created_at.lt.2026-11-21T00:00:01.000Z'));
      expect(query['or'], contains('id.lt.${page.single.id}'));
    },
  );
  test(
    'cuenta exacta del servidor incluye filtro de lectura y avisos habilitados',
    () async {
      expect(await repo.unreadCount(), 73);
      final request = api.requests.last;
      expect(request.method, 'HEAD');
      expect(request.headers['prefer'], contains('count=exact'));
      expect(request.url.queryParameters['read_at'], 'is.null');
      expect(request.url.queryParameters['alert_enabled'], 'eq.true');
      expect(request.url.queryParameters['recipient_id'], 'eq.$recoveryA');
    },
  );
  test(
    'preferencias predeterminadas y actualización por RPC ligada al actor',
    () async {
      api.noPreferences = true;
      expect((await repo.preferences()).messages, isTrue);
      final p = await repo.savePreferences(
        const NotificationPreferences(messages: false, matches: false),
      );
      expect(p.messages, isFalse);
      final request = api.requests.last,
          body = jsonDecode(api.requests.last.body) as Map;
      expect(request.method, 'POST');
      expect(
        request.url.path,
        endsWith('/rpc/encuentralo_save_notification_preferences'),
      );
      expect(body['p_actor'], recoveryA);
      expect(body['p_messages'], false);
      expect(body.containsKey('user_id'), isFalse);
    },
  );
  test('lectura individual, lote y tutorial solo usan RPC', () async {
    await repo.markRead(id: notification().id);
    var body = jsonDecode(api.requests.last.body) as Map;
    expect(body['p_actor'], recoveryA);
    expect(body['p_id'], notification().id);
    expect(body['p_before'], isNull);
    await repo.markRead(before: DateTime.utc(2026, 11, 21));
    body = jsonDecode(api.requests.last.body) as Map;
    expect(body['p_id'], isNull);
    expect(body['p_before'], '2026-11-21T00:00:00.000Z');
    await repo.completeTutorial();
    expect(
      api.requests.last.url.path,
      endsWith('/rpc/encuentralo_complete_tutorial'),
    );
    expect(api.requests.skip(1).every((r) => r.method == 'POST'), isTrue);
  });
  test(
    'sin sesión rechaza consulta, escritura y suscripción antes de HTTP',
    () async {
      await api.client.auth.signOut(scope: sb.SignOutScope.local);
      final count = api.requests.length;
      await expectLater(repo.page(), throwsA(isA<AuthException>()));
      await expectLater(
        repo.markRead(id: notification().id),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => repo.watch(changed: () {}, connection: (_) {}),
        throwsA(isA<AuthException>()),
      );
      expect(api.requests.length, count);
    },
  );
  test('respuesta tardía se descarta si el SDK cambia a otra cuenta', () async {
    api.beforeReply = () => api.login(recoveryB);
    await expectLater(repo.page(), throwsA(isA<AuthException>()));
  });
  test(
    'errores de permisos y migración ausente se traducen sin filtrar detalles',
    () async {
      api.error = '42501';
      await expectLater(repo.page(), throwsA(isA<PermissionException>()));
      for (final code in ['42P01', 'PGRST202', 'PGRST205', '42883']) {
        api.error = code;
        await expectLater(
          repo.page(),
          throwsA(
            isA<StorageException>().having(
              (e) => e.message,
              'message',
              contains('todavía no están disponibles'),
            ),
          ),
        );
      }
      api.error = 'XX000';
      await expectLater(
        repo.page(),
        throwsA(
          isA<StorageException>().having(
            (e) => e.message,
            'message',
            isNot(contains('PRIVATE')),
          ),
        ),
      );
    },
  );
}
