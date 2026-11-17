import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart' as app;
import '../local/supabase_auth_storage.dart';

/// One shared client. An unavailable backend never falls back to local auth.
class SupabaseService {
  SupabaseService({
    SupabaseClient? client,
    SupabaseClient Function()? recoveryClientFactory,
  }) : _client = client,
       _recoveryClientFactory = recoveryClientFactory;

  final SupabaseClient Function()? _recoveryClientFactory;

  SupabaseClient? _client;
  String? _initializationError;

  static String? configurationError(String url, String key) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host.toLowerCase().contains('your_project_ref') ||
        !key.startsWith('sb_publishable_') ||
        key.contains('REPLACE') ||
        key.trim() != key ||
        key.length <= 'sb_publishable_'.length) {
      return 'Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en '
          'config/supabase.local.json y ejecuta con '
          '--dart-define-from-file=config/supabase.local.json. '
          'Usa únicamente la Publishable Key (sb_publishable_).';
    }
    return null;
  }

  Future<void> initialize() async {
    _initializationError = configurationError(
      Env.supabaseUrl,
      Env.supabasePublishableKey,
    );
    if (_initializationError != null) return;
    try {
      final instance = await Supabase.initialize(
        url: Env.supabaseUrl,
        // The 2.9.1 SDK calls this argument anonKey; publishable keys work here.
        anonKey: Env.supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: false,
          pkceAsyncStorage: SupabasePkceStorage(
            projectHost: Uri.parse(Env.supabaseUrl).host,
          ),
          localStorage: SupabaseAuthStorage(
            projectHost: Uri.parse(Env.supabaseUrl).host,
          ),
        ),
        debug: false,
      );
      _client = instance.client;
    } catch (_) {
      _initializationError =
          'No se pudo inicializar Supabase. '
          'Revisa la configuración y reinicia la aplicación.';
    }
  }

  SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw app.AuthException(
        _initializationError ?? configurationError('', '')!,
      );
    }
    return value;
  }

  Stream<AuthState> get authChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  SupabaseClient createRecoveryClient() {
    client; // Check configuration before creating any temporary client.
    return _recoveryClientFactory?.call() ??
        SupabaseClient(
          Env.supabaseUrl,
          Env.supabasePublishableKey,
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.pkce,
            pkceAsyncStorage: SupabasePkceStorage(
              projectHost: Uri.parse(Env.supabaseUrl).host,
            ),
          ),
        );
  }
}
