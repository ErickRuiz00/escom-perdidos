import 'dart:io';

import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/local/seed_data.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'se conserva la compatibilidad de custodia en SQLite heredado',
    () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      await SeedData.ensure(db);
      final repository = ReportRepository(db);
      final user = AppUser(
        id: 'remote-user',
        name: 'Ana',
        email: 'ana@example.org',
        provider: 'supabase',
        createdAt: DateTime(2026),
      );
      await (await db.database).insert('users', user.toMap());
      final report = Report(
        id: 'real-local',
        userId: user.id,
        type: ReportType.found,
        title: 'Termo',
        description: 'Termo azul sin nombre',
        category: ItemCategory.bottles,
        location: 'Biblioteca',
        eventDate: DateTime(2026),
        status: ReportStatus.active,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        custody: ItemCustody.prefecture,
      );
      await repository.create(report);
      expect(
        (await repository.findById(report.id))!.custody,
        ItemCustody.prefecture,
      );
      expect(await repository.fetchAll(), hasLength(7));
      await repository.update(report.copyWith(custody: ItemCustody.student));
      expect(
        (await repository.findById(report.id))!.custody,
        ItemCustody.student,
      );
    },
  );

  test(
    'SQLite v1 pasa a v2 sin perder usuarios ni reportes anteriores',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp(
        'encuentralo-migration-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/legacy.db';
      final first = AppDatabase(factory: databaseFactoryFfi, path: path);
      await SeedData.ensure(first);
      final original = await ReportRepository(first).fetchAll();
      final connection = await first.database;
      await connection.execute('ALTER TABLE reports DROP COLUMN custody');
      await connection.setVersion(1);
      await first.close();
      final upgraded = AppDatabase(factory: databaseFactoryFfi, path: path);
      addTearDown(upgraded.close);
      final restored = await ReportRepository(upgraded).fetchAll();
      expect(restored.map((r) => r.id), original.map((r) => r.id));
      expect(restored.every((r) => r.custody == null), isTrue);
      expect((await (await upgraded.database).query('users')), hasLength(1));
      final changed = restored.first.copyWith(custody: ItemCustody.prefecture);
      await ReportRepository(upgraded).update(changed);
      expect(
        (await ReportRepository(upgraded).findById(changed.id))!.custody,
        ItemCustody.prefecture,
      );
    },
  );
}
