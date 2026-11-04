import 'package:escom_perdidos/core/security/jwt_service.dart';
import 'package:escom_perdidos/core/security/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordHasher', () {
    const hasher = PasswordHasher(iterations: 1000);

    test('verifica la contraseña correcta y rechaza la incorrecta', () {
      final salt = hasher.generateSalt();
      final hash = hasher.hash('Escom2026', salt);
      expect(hasher.verify('Escom2026', salt, hash), isTrue);
      expect(hasher.verify('escom2026', salt, hash), isFalse);
    });

    test('la misma contraseña con distinta sal produce hashes distintos', () {
      final a = hasher.hash('Escom2026', hasher.generateSalt());
      final b = hasher.hash('Escom2026', hasher.generateSalt());
      expect(a, isNot(b));
    });

    test('nunca contiene la contraseña en claro', () {
      final hash = hasher.hash('Escom2026', hasher.generateSalt());
      expect(hash.contains('Escom2026'), isFalse);
    });
  });

  group('JwtService', () {
    const jwt = JwtService();
    const secret = 'secreto';

    test('emite un token válido con el id del usuario', () {
      final token = jwt.issue(userId: 'u1', email: 'a@ipn.mx', secret: secret);
      expect(token.split('.'), hasLength(3));
      expect(jwt.verify(token, secret)?['sub'], 'u1');
    });

    test('rechaza tokens con otra llave o alterados', () {
      final token = jwt.issue(userId: 'u1', email: 'a@ipn.mx', secret: secret);
      expect(jwt.verify(token, 'otra-llave'), isNull);
      final parts = token.split('.');
      expect(jwt.verify('${parts[0]}.${parts[1]}x.${parts[2]}', secret), isNull);
    });

    test('rechaza tokens expirados', () {
      final issuedAt = DateTime(2026, 1, 1);
      final token = jwt.issue(
        userId: 'u1',
        email: 'a@ipn.mx',
        secret: secret,
        now: issuedAt,
        ttl: const Duration(hours: 1),
      );
      expect(jwt.verify(token, secret, now: issuedAt.add(const Duration(minutes: 30))),
          isNotNull);
      expect(jwt.verify(token, secret, now: issuedAt.add(const Duration(hours: 2))),
          isNull);
    });
  });
}
