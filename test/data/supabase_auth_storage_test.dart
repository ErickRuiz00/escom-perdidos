import 'package:escom_perdidos/data/local/supabase_auth_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PKCE verifier survives restart and remains separate from sessions and projects',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SupabasePkceStorage(projectHost: 'dev.supabase.co');
      await storage.setItem(key: 'verifier', value: 'device-secret');
      final reopened = SupabasePkceStorage(projectHost: 'dev.supabase.co');
      expect(await reopened.getItem(key: 'verifier'), 'device-secret');
      expect(
        await SupabasePkceStorage(
          projectHost: 'other.supabase.co',
        ).getItem(key: 'verifier'),
        isNull,
      );
      expect(
        await SupabaseAuthStorage(
          projectHost: 'dev.supabase.co',
        ).hasAccessToken(),
        isFalse,
      );
      await reopened.removeItem(key: 'verifier');
      expect(await storage.getItem(key: 'verifier'), isNull);
    },
  );

  test(
    'persists session across storage instances, isolates projects and removes it',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'session_token': 'legacy-token',
      });
      final storage = SupabaseAuthStorage(projectHost: 'dev.supabase.co');
      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      const json =
          '{"access_token":"server-session","refresh_token":"refresh"}';
      await storage.persistSession(json);
      final reopened = SupabaseAuthStorage(projectHost: 'dev.supabase.co');
      expect(await reopened.accessToken(), json);
      expect(
        await SupabaseAuthStorage(
          projectHost: 'other.supabase.co',
        ).hasAccessToken(),
        isFalse,
      );
      await reopened.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'session_token'),
        'legacy-token',
      );
    },
  );
}
