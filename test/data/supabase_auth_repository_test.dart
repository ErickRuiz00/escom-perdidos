import 'dart:convert';
import 'dart:async';

import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/services/supabase_service.dart';
import 'package:escom_perdidos/data/services/auth_link_service.dart';
import 'package:escom_perdidos/viewmodels/auth_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers.dart';

const _id = 'd552bd44-18b0-48be-8077-87c2c087455d';

class _PkceStorage extends sb.GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

/// Only HTTP is mocked: the real Supabase SDK performs all Auth/REST calls.
/// These tests do not assert that a hosted Supabase project is configured.
class _Backend {
  final requests = <http.Request>[];
  bool rejectLogin = false;
  bool rejectCode = false;
  bool missingProfile = false;
  bool rejectProfile = false;
  bool rejectLink = false;
  final profile = <String, dynamic>{
    'id': _id,
    'name': 'Ana López',
    'boleta': null,
    'phone': null,
    'notifications_enabled': true,
    'dark_mode': false,
  };

  Map<String, dynamic> get user => {
    'id': _id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'ana@example.org',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {'name': 'Ana López'},
    'created_at': '2026-11-17T12:00:00Z',
    'email_confirmed_at': '2026-11-17T12:01:00Z',
  };

  Map<String, dynamic> get session {
    final claims = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': _id,
              'role': 'authenticated',
              'exp':
                  DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    return {
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.signature',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': user,
    };
  }

  sb.SupabaseClient client({sb.GotrueAsyncStorage? pkceStorage}) =>
      sb.SupabaseClient(
        'https://test-project.supabase.co',
        'sb_publishable_test',
        authOptions: sb.AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: pkceStorage == null
              ? sb.AuthFlowType.implicit
              : sb.AuthFlowType.pkce,
          pkceAsyncStorage: pkceStorage,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          final body = request.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>;
          final path = request.url.path;
          Object response;
          var status = 200;
          if (path.endsWith('/signup')) {
            response = {...user, 'email_confirmed_at': null};
          } else if (path.endsWith('/token')) {
            status = rejectLogin ? 400 : 200;
            response = rejectLogin
                ? {
                    'code': 'invalid_credentials',
                    'msg': 'Invalid login credentials',
                  }
                : session;
          } else if (path.endsWith('/verify')) {
            status = rejectCode ? 403 : 200;
            response = rejectCode
                ? {'code': 'otp_expired', 'msg': 'Token expired'}
                : session;
          } else if (path.endsWith('/user')) {
            status = rejectLink && request.method == 'GET' ? 401 : 200;
            response = status == 401
                ? {'code': 'bad_jwt', 'msg': 'Invalid JWT'}
                : user;
          } else if (path.endsWith('/profiles')) {
            if (rejectProfile) {
              status = 403;
              response = {'code': '42501', 'message': 'permission denied'};
            } else if (request.method == 'PATCH') {
              profile.addAll(body);
              response = {'id': _id};
            } else {
              response = missingProfile ? [] : [profile];
            }
          } else if (path.endsWith('/logout')) {
            status = 204;
            response = {};
          } else if (path.endsWith('/recover') || path.endsWith('/resend')) {
            response = {};
          } else {
            throw StateError('Unexpected endpoint: ${request.method} $path');
          }
          return http.Response(
            status == 204 ? '' : jsonEncode(response),
            status,
            request: request,
            headers: {
              'content-type': 'application/json',
              'x-supabase-api-version': '2024-01-01',
            },
          );
        }),
      );

  Uri link(String type, {String? redirect}) {
    final data = session;
    return Uri.parse(
      '${redirect ?? (type == 'recovery' ? AuthLinkService.recoveryRedirect : AuthLinkService.confirmationRedirect)}#'
      '${Uri(queryParameters: {'access_token': data['access_token'], 'refresh_token': data['refresh_token'], 'token_type': 'bearer', 'expires_in': '3600', 'type': type}).query}',
    );
  }
}

void main() {
  late AppDatabase database;
  late FakeSecureStore secure;
  late _Backend backend;
  late sb.SupabaseClient client;
  late AuthRepository repository;

  setUp(() {
    database = memoryDatabase();
    secure = FakeSecureStore();
    backend = _Backend();
    client = backend.client();
    repository = AuthRepository(
      emailOtpEnabled: true,
      database: database,
      secureStore: secure,
      supabase: SupabaseService(
        client: client,
        recoveryClientFactory: backend.client,
      ),
    );
  });

  tearDown(() async {
    await repository.cancelPasswordRecovery();
    await client.dispose();
    await database.close();
  });

  test(
    'missing config never accepts legacy tokens or local credentials',
    () async {
      secure.token = 'old-local-token';
      final unavailable = AuthRepository(
        database: database,
        secureStore: secure,
        supabase: SupabaseService(),
      );
      final vm = AuthViewModel(unavailable);
      addTearDown(vm.dispose);
      await vm.restoreSession();
      expect(vm.status, AuthStatus.unauthenticated);
      expect(vm.error, contains('--dart-define-from-file'));
      expect(secure.token, isNull);
      expect(await vm.login('ana@example.org', 'Password2026'), isFalse);
      expect(vm.user, isNull);
      await expectLater(
        unavailable.register(
          name: 'Ana',
          email: 'ana@example.org',
          password: 'Password2026',
        ),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        unavailable.requestPasswordReset('ana@example.org'),
        throwsA(isA<AuthException>()),
      );
      expect(backend.requests, isEmpty);
    },
  );

  test('configuration accepts only HTTPS and publishable keys', () {
    expect(
      SupabaseService.configurationError(
        'https://test.supabase.co',
        'sb_publishable_publicvalue',
      ),
      isNull,
    );
    for (final key in ['', 'sb_secret_private', 'service_role', 'eyJhbGciOi']) {
      expect(
        SupabaseService.configurationError('https://test.supabase.co', key),
        isNotNull,
      );
    }
    expect(
      SupabaseService.configurationError(
        'http://test.supabase.co',
        'sb_publishable_publicvalue',
      ),
      isNotNull,
    );
  });

  test(
    'signup sends password to Auth and waits for confirmation without caching',
    () async {
      final vm = AuthViewModel(repository);
      addTearDown(vm.dispose);
      expect(
        await vm.register(
          name: 'Ana López',
          email: ' ANA@Example.ORG ',
          password: 'Password2026',
        ),
        isTrue,
      );
      expect(vm.status, AuthStatus.unauthenticated);
      expect(vm.user, isNull);
      expect(client.auth.currentSession, isNull);
      final body = jsonDecode(backend.requests.single.body);
      expect(body['email'], 'ana@example.org');
      expect(body['password'], 'Password2026');
      expect(await (await database.database).query('users'), isEmpty);
    },
  );

  test(
    'confirmation verifies emailed OTP with Auth and loads private profile',
    () async {
      final user = await repository.confirmEmail('ana@example.org', '123456');
      expect(user.id, _id);
      expect(client.auth.currentSession, isNotNull);
      final body = jsonDecode(backend.requests.first.body);
      expect(body['type'], 'email');
      expect(body['token'], '123456');
      await repository.resendConfirmation('ana@example.org');
      expect(backend.requests.last.url.path, '/auth/v1/resend');
    },
  );

  test(
    'login caches UUID without password and preserves legacy account and reports',
    () async {
      final db = await database.database;
      await db.insert('users', {
        'id': 'legacy',
        'name': 'Ana local',
        'email': 'ana@example.org',
        'provider': 'local',
        'created_at': 0,
        'password_hash': 'legacy-hash',
        'password_salt': 'legacy-salt',
      });
      final user = await repository.login('ana@example.org', 'Password2026');
      expect(user.email, 'ana@example.org');
      final rows = await db.query('users', where: 'id = ?', whereArgs: [_id]);
      expect(rows.single['password_hash'], isNull);
      expect(rows.single['password_salt'], isNull);
      expect(
        (await db.query(
          'users',
          where: 'id = ?',
          whereArgs: ['legacy'],
        )).single['password_hash'],
        'legacy-hash',
      );
      await db.insert('reports', {
        'id': 'r1',
        'user_id': user.id,
        'type': 'lost',
        'title': 'Audífonos',
        'description': 'Audífonos blancos',
        'category': 'electronics',
        'location': 'Biblioteca',
        'event_date': 0,
        'status': 'active',
        'created_at': 0,
        'updated_at': 0,
      });
      await repository.updateProfile(
        user.copyWith(name: 'Ana nueva', darkMode: true),
      );
      expect(await db.query('reports'), hasLength(1));
      expect(backend.profile['dark_mode'], isTrue);
      expect(backend.profile.containsKey('avatar_path'), isFalse);
    },
  );

  test(
    'login errors and missing/RLS denied profiles never authorize Home',
    () async {
      final vm = AuthViewModel(repository);
      addTearDown(vm.dispose);
      await vm.restoreSession();
      backend.rejectLogin = true;
      expect(await vm.login('ana@example.org', 'bad'), isFalse);
      expect(vm.error, 'Correo o contraseña incorrectos.');
      expect(vm.status, AuthStatus.unauthenticated);
      backend.rejectLogin = false;
      backend.missingProfile = true;
      expect(await vm.login('ana@example.org', 'Password2026'), isFalse);
      expect(vm.error, contains('migración'));
      expect(vm.user, isNull);
      backend.missingProfile = false;
      backend.rejectProfile = true;
      expect(await vm.login('ana@example.org', 'Password2026'), isFalse);
      expect(vm.error, contains('RLS'));
      expect(vm.user, isNull);
    },
  );

  test(
    'restores only SDK session, checks server user and closes session',
    () async {
      await repository.login('ana@example.org', 'Password2026');
      final storedSession = jsonEncode(client.auth.currentSession!.toJson());
      final restarted = backend.client();
      addTearDown(restarted.dispose);
      await restarted.auth.recoverSession(storedSession);
      final restored = AuthRepository(
        database: database,
        secureStore: secure,
        supabase: SupabaseService(client: restarted),
      );
      expect((await restored.restoreSession())?.id, _id);
      expect(
        backend.requests.any(
          (r) => r.method == 'GET' && r.url.path == '/auth/v1/user',
        ),
        isTrue,
      );
      await restored.logout();
      expect(restarted.auth.currentSession, isNull);
      expect(await restored.restoreSession(), isNull);
    },
  );

  test(
    'recovery sends email, verifies OTP and updates password without main session',
    () async {
      final vm = AuthViewModel(repository);
      addTearDown(vm.dispose);
      await vm.restoreSession();
      expect(await vm.requestPasswordReset('ana@example.org'), isTrue);
      expect(backend.requests.last.url.path, '/auth/v1/recover');
      expect(
        await vm.resetPassword(
          email: 'ana@example.org',
          code: '123456',
          newPassword: 'NewPassword2026',
        ),
        isTrue,
      );
      expect(vm.status, AuthStatus.unauthenticated);
      expect(client.auth.currentSession, isNull);
      final verify = backend.requests.firstWhere(
        (r) => r.url.path.endsWith('/verify'),
      );
      expect(jsonDecode(verify.body)['type'], 'recovery');
      final update = backend.requests.firstWhere((r) => r.method == 'PUT');
      expect(jsonDecode(update.body)['password'], 'NewPassword2026');
    },
  );

  test(
    'invalid recovery code never changes password or opens a session',
    () async {
      backend.rejectCode = true;
      await expectLater(
        repository.resetPassword(
          email: 'ana@example.org',
          code: '000000',
          newPassword: 'NewPassword2026',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(backend.requests.any((r) => r.method == 'PUT'), isFalse);
      expect(client.auth.currentSession, isNull);
    },
  );

  test(
    'changing password reauthenticates and rejects the wrong current password',
    () async {
      final user = await repository.login('ana@example.org', 'Password2026');
      backend.rejectLogin = true;
      await expectLater(
        repository.changePassword(
          userId: user.id,
          currentPassword: 'wrong',
          newPassword: 'NewPassword2026',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(backend.requests.any((r) => r.method == 'PUT'), isFalse);
      backend.rejectLogin = false;
      await repository.changePassword(
        userId: user.id,
        currentPassword: 'Password2026',
        newPassword: 'NewPassword2026',
      );
      final update = backend.requests.lastWhere((r) => r.method == 'PUT');
      expect(jsonDecode(update.body)['password'], 'NewPassword2026');
      expect(update.url.path, '/auth/v1/user');
    },
  );

  test(
    'standard signup/resend/recovery use callbacks without editable templates',
    () async {
      final standard = AuthRepository(
        database: database,
        secureStore: secure,
        supabase: SupabaseService(client: client),
      );
      expect(standard.emailOtpEnabled, isFalse);
      await standard.register(
        name: 'Ana',
        email: 'ana@example.org',
        password: 'Password2026',
      );
      expect(
        backend.requests.last.url.queryParameters['redirect_to'],
        AuthLinkService.confirmationRedirect,
      );
      await standard.resendConfirmation('ana@example.org');
      expect(
        backend.requests.last.url.queryParameters['redirect_to'],
        AuthLinkService.confirmationRedirect,
      );
      await standard.requestPasswordReset('ana@example.org');
      expect(
        backend.requests.last.url.queryParameters['redirect_to'],
        AuthLinkService.recoveryRedirect,
      );
      await expectLater(
        standard.confirmEmail('ana@example.org', '123456'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        standard.resetPassword(
          email: 'ana@example.org',
          code: '123456',
          newPassword: 'NewPassword2026',
        ),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'confirmation link is checked by server and still requires password login',
    () async {
      expect(await repository.openAuthLink(backend.link('signup')), isFalse);
      expect(client.auth.currentSession, isNull);
      expect(await (await database.database).query('users'), isEmpty);
      expect(
        backend.requests.any(
          (r) => r.method == 'GET' && r.url.path.endsWith('/user'),
        ),
        isTrue,
      );
    },
  );

  test(
    'cold recovery never restores Home and changes password on temporary client',
    () async {
      final links = AuthLinkService()..receive(backend.link('recovery'));
      final vm = AuthViewModel(repository, links: links);
      addTearDown(links.dispose);
      addTearDown(vm.dispose);
      await vm.restoreSession();
      expect(vm.status, AuthStatus.passwordRecovery);
      expect(vm.user, isNull);
      expect(client.auth.currentSession, isNull);
      expect(await vm.finishPasswordRecovery('NewPassword2026'), isTrue);
      expect(vm.status, AuthStatus.unauthenticated);
      expect(vm.notice, contains('Contraseña actualizada'));
      expect(
        jsonDecode(
          backend.requests.lastWhere((r) => r.method == 'PUT').body,
        )['password'],
        'NewPassword2026',
      );
      expect(await vm.finishPasswordRecovery('AnotherPassword2026'), isFalse);
    },
  );

  test(
    'recovery link during an existing session removes that session and can cancel',
    () async {
      final links = AuthLinkService();
      final vm = AuthViewModel(repository, links: links);
      addTearDown(links.dispose);
      addTearDown(vm.dispose);
      expect(await vm.login('ana@example.org', 'Password2026'), isTrue);
      final completed = Completer<void>();
      vm.addListener(() {
        if (vm.status == AuthStatus.passwordRecovery &&
            !vm.busy &&
            !completed.isCompleted) {
          completed.complete();
        }
      });
      links.receive(backend.link('recovery'));
      await completed.future.timeout(const Duration(seconds: 5));
      expect(vm.user, isNull);
      expect(client.auth.currentSession, isNull);
      expect(await vm.cancelPasswordRecovery(), isTrue);
      expect(await vm.finishPasswordRecovery('NewPassword2026'), isFalse);
      expect(backend.requests.any((r) => r.method == 'PUT'), isFalse);
    },
  );

  test(
    'invalid, expired and wrong-operation links never authorize password updates',
    () async {
      final bad = Uri.parse(
        '${AuthLinkService.recoveryRedirect}#error=access_denied&error_code=otp_expired&error_description=Expired',
      );
      await expectLater(
        repository.openAuthLink(bad),
        throwsA(isA<AuthException>()),
      );
      backend.rejectLink = true;
      await expectLater(
        repository.openAuthLink(backend.link('recovery')),
        throwsA(isA<AuthException>()),
      );
      backend.rejectLink = false;
      await expectLater(
        repository.openAuthLink(
          backend.link('signup', redirect: AuthLinkService.recoveryRedirect),
        ),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        repository.finishPasswordRecovery('NewPassword2026'),
        throwsA(isA<AuthException>()),
      );
      expect(client.auth.currentSession, isNull);
      expect(backend.requests.any((r) => r.method == 'PUT'), isFalse);
    },
  );

  test(
    'PKCE confirmation and recovery exchange only a code bound to the requesting device',
    () async {
      final storage = _PkceStorage();
      final pkceClient = backend.client(pkceStorage: storage);
      addTearDown(pkceClient.dispose);
      final pkceRepository = AuthRepository(
        database: database,
        secureStore: secure,
        supabase: SupabaseService(
          client: pkceClient,
          recoveryClientFactory: () => backend.client(pkceStorage: storage),
        ),
      );
      addTearDown(pkceRepository.cancelPasswordRecovery);
      await pkceRepository.register(
        name: 'Ana',
        email: 'ana@example.org',
        password: 'Password2026',
      );
      expect(
        jsonDecode(backend.requests.last.body)['code_challenge_method'],
        's256',
      );
      final originalVerifier = storage.values.values.single.split('/').first;
      expect(
        await pkceRepository.openAuthLink(
          Uri.parse(
            '${AuthLinkService.confirmationRedirect}?code=confirmation-code',
          ),
        ),
        isFalse,
      );
      final exchange = backend.requests.firstWhere(
        (r) => r.url.queryParameters['grant_type'] == 'pkce',
      );
      expect(jsonDecode(exchange.body)['code_verifier'], originalVerifier);
      expect(jsonDecode(exchange.body)['auth_code'], 'confirmation-code');
      expect(storage.values, isEmpty);
      expect(pkceClient.auth.currentSession, isNull);
      await pkceRepository.requestPasswordReset('ana@example.org');
      expect(
        await pkceRepository.openAuthLink(
          Uri.parse('${AuthLinkService.recoveryRedirect}?code=recovery-code'),
        ),
        isTrue,
      );
      expect(pkceClient.auth.currentSession, isNull);
      await pkceRepository.finishPasswordRecovery('NewPassword2026');
      expect(storage.values, isEmpty);
    },
  );

  test(
    'PKCE link without the original device verifier cannot start recovery',
    () async {
      final storage = _PkceStorage();
      final pkceClient = backend.client(pkceStorage: storage);
      addTearDown(pkceClient.dispose);
      final pkceRepository = AuthRepository(
        database: database,
        secureStore: secure,
        supabase: SupabaseService(
          client: pkceClient,
          recoveryClientFactory: () => backend.client(pkceStorage: storage),
        ),
      );
      await expectLater(
        pkceRepository.openAuthLink(
          Uri.parse('${AuthLinkService.recoveryRedirect}?code=foreign-code'),
        ),
        throwsA(isA<AuthException>()),
      );
      expect(backend.requests, isEmpty);
      await expectLater(
        pkceRepository.finishPasswordRecovery('NewPassword2026'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('server signout removes authenticated state', () async {
    final vm = AuthViewModel(repository);
    addTearDown(vm.dispose);
    expect(await vm.login('ana@example.org', 'Password2026'), isTrue);
    await client.auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(vm.status, AuthStatus.unauthenticated);
    expect(vm.user, isNull);
  });
}
