import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/local/seed_data.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

// Report tests create their own local author fixture; Auth is now remote.
Future<AppUser> _createLocalUser(AppDatabase database) async {
  final user = AppUser(
    id: 'report-owner',
    name: 'Ana',
    email: 'ana@ipn.mx',
    provider: 'local',
    createdAt: DateTime(2026),
  );
  await (await database.database).insert('users', user.toMap());
  return user;
}

void main() {
  late AppDatabase database;
  setUp(() => database = memoryDatabase());
  tearDown(() => database.close());

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
      final user = await _createLocalUser(database);
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

    test(
      'encuentra coincidencias del tipo contrario de otros usuarios',
      () async {
        await SeedData.ensure(database);
        final user = await _createLocalUser(database);
        final mine = newReport('r1', user.id, ReportType.lost);
        await reports.create(mine);
        await reports.create(
          newReport('r2', SeedData.systemUserId, ReportType.found),
        );

        final matches = await reports.findMatches(mine);
        expect(matches.map((r) => r.id), contains('r2'));
        expect(matches.every((r) => r.type == ReportType.found), isTrue);
        expect(matches.every((r) => r.userId != user.id), isTrue);
      },
    );

    test('los datos de ejemplo se insertan una sola vez', () async {
      await SeedData.ensure(database);
      await SeedData.ensure(database);
      expect(await reports.fetchAll(), hasLength(6));
    });
  });
}
