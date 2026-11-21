import 'dart:convert';
import 'dart:io';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/models/recovery.dart';
import 'package:escom_perdidos/data/repositories/recovery_repository.dart';
import 'package:escom_perdidos/data/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../recovery_helpers.dart';

class _Api {
  String uid = recoveryB;
  String? errorCode;
  bool loseReply = false;
  Future<void> Function()? beforeReply;
  final requests = <http.Request>[];
  late final client = sb.SupabaseClient(
    'https://test.supabase.co',
    'sb_publishable_test',
    authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );
  http.Response json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    request: requests.last,
    headers: {'content-type': 'application/json'},
  );
  Future<void> login(String user) async {
    uid = user;
    await client.auth.signInWithPassword(
      email: 'test@example.org',
      password: 'test-password',
    );
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/auth/v1/token') {
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
    if (errorCode != null) {
      return json({
        'code': errorCode,
        'message': errorCode == 'P0001'
            ? 'Espera dos segundos antes de enviar otro mensaje.'
            : 'controlled error',
      }, 400);
    }
    final callback = beforeReply;
    beforeReply = null;
    await callback?.call();
    if (path.contains('/rpc/')) {
      if (loseReply) {
        loseReply = false;
        throw const SocketException('Controlled lost reply');
      }
      final body = jsonDecode(request.body) as Map;
      if (path.endsWith('encuentralo_send_message')) {
        return json({
          'id': body['p_id'],
          'conversation_id': body['p_conversation_id'],
          'sender_id': body['p_actor'],
          'body': body['p_body'],
          'created_at': '2026-11-21T12:00:00Z',
        });
      }
      if (path.endsWith('encuentralo_block_user') ||
          path.endsWith('encuentralo_report_abuse')) {
        return json(null);
      }
      return json({
        ...recoveryRow(),
        'id': body['p_id'],
        'evidence': body['p_evidence'] ?? recoveryRow()['evidence'],
      });
    }
    if (path.endsWith('recovery_requests')) return json([recoveryRow()]);
    if (path.endsWith('recovery_messages')) {
      return json([
        {
          'id': recoveryId,
          'conversation_id': recoveryConversation,
          'sender_id': recoveryA,
          'body': 'Mensaje de prueba',
          'created_at': '2026-11-21T12:00:00Z',
        },
      ]);
    }
    return json([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late RecoveryRepository repository;
  setUp(() async {
    api = _Api();
    await api.login(recoveryB);
    repository = RecoveryRepository(SupabaseService(client: api.client));
  });
  tearDown(() => api.client.dispose());
  test(
    'cancelación de suscripción es idempotente y tolera pérdida de red',
    () async {
      var calls = 0;
      final subscription = RecoverySubscription(() async {
        calls++;
        throw const SocketException('fallo de cierre simulado');
      });
      await subscription.cancel();
      await subscription.cancel();
      expect(calls, 1);
    },
  );
  test(
    'RPC liga actor a sesión, UUID estable y evidencia privada sin perfiles',
    () async {
      final evidence = '  Una marca privada debajo de la tapa  ';
      await repository.create(
        id: recoveryId,
        itemId: recoveryItem,
        evidence: evidence,
      );
      final sent = api.requests.last;
      expect(sent.url.path, '/rest/v1/rpc/encuentralo_request_recovery');
      expect(jsonDecode(sent.body), {
        'p_actor': recoveryB,
        'p_id': recoveryId,
        'p_item_id': recoveryItem,
        'p_evidence': evidence.trim(),
      });
      expect(api.requests.any((r) => r.url.path.contains('profiles')), isFalse);
      api.loseReply = true;
      await expectLater(
        repository.create(
          id: recoveryId,
          itemId: recoveryItem,
          evidence: evidence,
        ),
        throwsA(isA<NetworkException>()),
      );
      await repository.create(
        id: recoveryId,
        itemId: recoveryItem,
        evidence: evidence,
      );
      expect(
        api.requests
            .where((r) => r.url.path.endsWith('encuentralo_request_recovery'))
            .map((r) => jsonDecode(r.body)['p_id'])
            .toSet(),
        {recoveryId},
      );
    },
  );
  test(
    'acciones envían versión y horario UTC, no estados ni autoría arbitrarios',
    () async {
      final r = RecoveryRequest.fromJson(recoveryRow());
      await repository.act(
        r,
        'meeting',
        point: 'Explanada',
        at: DateTime(2026, 11, 22, 14),
      );
      final body = jsonDecode(api.requests.last.body) as Map;
      expect(body['p_actor'], recoveryB);
      expect(body['p_version'], 1);
      expect(body['p_action'], 'meeting');
      expect(body['p_meeting_at'], endsWith('Z'));
      expect(body.containsKey('finder_id'), isFalse);
      expect(body.containsKey('status'), isFalse);
    },
  );
  test(
    'mensajes paginados con cursor estable, filtro de conversación y límite',
    () async {
      final first = (await repository.messages(recoveryConversation)).single;
      await repository.messages(recoveryConversation, before: first);
      final query = api.requests.last.url.queryParameters;
      expect(query['conversation_id'], 'eq.$recoveryConversation');
      expect(query['limit'], '50');
      expect(query['or'], contains('id.lt.${first.id}'));
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      await repository.messages(recoveryConversation, after: first);
      expect(
        api.requests.last.url.queryParameters['or'],
        contains('id.gt.${first.id}'),
      );
      expect(
        api.requests.last.url.queryParameters['order'],
        'created_at.asc.nullslast,id.asc.nullslast',
      );
    },
  );
  test(
    'envío de mensaje preserva UUID y no acepta remitente del formulario',
    () async {
      await repository.send(
        id: recoveryId,
        conversationId: recoveryConversation,
        body: ' Hola ',
      );
      expect(jsonDecode(api.requests.last.body), {
        'p_actor': recoveryB,
        'p_id': recoveryId,
        'p_conversation_id': recoveryConversation,
        'p_body': 'Hola',
      });
      final count = api.requests.length;
      await expectLater(
        repository.send(
          id: recoveryId,
          conversationId: recoveryConversation,
          body: ' ',
        ),
        throwsA(isA<AppException>()),
      );
      expect(api.requests.length, count);
    },
  );
  test(
    'detalle/listado privado tardío no se devuelve tras cambiar de cuenta',
    () async {
      api.beforeReply = () => api.login(recoveryC);
      await expectLater(repository.requests(), throwsA(isA<AuthException>()));
    },
  );
  test(
    'errores de migración, permisos, versión y límite se muestran en español',
    () async {
      for (final entry in {
        'PGRST202': 'todavía no está disponible',
        '42501': 'no está disponible para tu cuenta',
        '40001': 'La solicitud cambió',
        '23505': 'Ya tienes una solicitud activa',
        'P0001': 'Espera dos segundos',
      }.entries) {
        api.errorCode = entry.key;
        await expectLater(
          repository.requests(),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'mensaje',
              contains(entry.value),
            ),
          ),
        );
      }
    },
  );
}
