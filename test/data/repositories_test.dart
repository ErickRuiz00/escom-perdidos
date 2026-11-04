import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/local/seed_data.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/repositories/auth_repository.dart';
import 'package:escom_perdidos/data/repositories/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase database;
  late FakeSecureStore secure;
  late AuthRepository auth;

  setUp(() {
    database = memoryDatabase();
    secure = FakeSecureStore();
    auth = AuthRepository(database: database, secureStore: secure);
  });

  tearDown(() => database.close());

  group('AuthRepository', () {
    test('registro guarda hash, abre sesión y permite login', () async {
      final user = await auth.register(
        name: 'Erick Ruiz',
        email: 'Erick@Alumno.ipn.mx',
        password: 'Escom2026',
      );
      expect(user.email, 'erick@alumno.ipn.mx');
      expect(secure.token, isNotNull);

      final db = await database.database;
      final row = (await db.query('users', where: 'id = ?', whereArgs: [user.id])).single;
      expect(row['password_hash'], isNot('Escom2026'));

      await auth.logout();
      expect(secure.token, isNull);
      final logged = await auth.login('erick@alumno.ipn.mx', 'Escom2026');
      expect(logged.id, user.id);
    });

    test('rechaza correo duplicado y contraseña incorrecta', () async {
      await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      await expectLater(
        () => auth.register(name: 'Ana 2', email: 'ana@ipn.mx', password: 'Escom2026'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        () => auth.login('ana@ipn.mx', 'otra1234'),
        throwsA(isA<AuthException>()),
      );
    });

    test('restaura la sesión desde el token', () async {
      final user =
          await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      expect((await auth.restoreSession())?.id, user.id);
      secure.token = 'token.invalido.x';
      expect(await auth.restoreSession(), isNull);
      expect(secure.token, isNull);
    });

    test('recuperación de contraseña con código', () async {
      await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      final code = await auth.requestPasswordReset('ana@ipn.mx');
      expect(code, hasLength(6));
      await expectLater(
        () => auth.resetPassword(email: 'ana@ipn.mx', code: '000000', newPassword: 'Nueva2026'),
        throwsA(isA<AuthException>()),
      );
      await auth.resetPassword(email: 'ana@ipn.mx', code: code, newPassword: 'Nueva2026');
      expect((await auth.login('ana@ipn.mx', 'Nueva2026')).email, 'ana@ipn.mx');
    });

    test('actualiza el perfil', () async {
      final user =
          await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      final updated = await auth.updateProfile(
        user.copyWith(name: 'Ana López', boleta: '2021630796', darkMode: true),
      );
      expect(updated.name, 'Ana López');
      expect(updated.boleta, '2021630796');
      expect(updated.darkMode, isTrue);
    });
  });

  group('ReportRepository', () {
    late ReportRepository reports;

    setUp(() => reports = ReportRepository(database));

    Report newReport(String id, String userId, ReportType type) {
      final now = DateTime.now();
      return Report(
        id: id,
        userId: userId,
        type: type,
        title: 'Audífonos',
        description: 'Audífonos blancos con estuche',
        category: ItemCategory.electronics,
        location: 'Biblioteca',
        eventDate: now,
        status: ReportStatus.active,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('CRUD completo', () async {
      final user =
          await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      final report = newReport('r1', user.id, ReportType.lost);

      await reports.create(report);
      final saved = await reports.findById('r1');
      expect(saved?.title, 'Audífonos');
      expect(saved?.authorName, 'Ana');

      await reports.update(report.copyWith(title: 'Audífonos Sony'));
      expect((await reports.findById('r1'))?.title, 'Audífonos Sony');

      await reports.delete('r1');
      expect(await reports.findById('r1'), isNull);
    });

    test('encuentra coincidencias del tipo contrario de otros usuarios', () async {
      await SeedData.ensure(database);
      final user =
          await auth.register(name: 'Ana', email: 'ana@ipn.mx', password: 'Escom2026');
      final mine = newReport('r1', user.id, ReportType.lost);
      await reports.create(mine);
      await reports.create(newReport('r2', SeedData.systemUserId, ReportType.found));

      final matches = await reports.findMatches(mine);
      expect(matches.map((r) => r.id), contains('r2'));
      expect(matches.every((r) => r.type == ReportType.found), isTrue);
      expect(matches.every((r) => r.userId != user.id), isTrue);
    });

    test('los datos de ejemplo se insertan una sola vez', () async {
      await SeedData.ensure(database);
      await SeedData.ensure(database);
      expect(await reports.fetchAll(), hasLength(6));
    });
  });
}
