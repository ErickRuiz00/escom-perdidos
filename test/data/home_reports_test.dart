import 'dart:io';

import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/core/errors/app_exception.dart';
import 'package:escom_perdidos/data/local/app_database.dart';
import 'package:escom_perdidos/data/local/seed_data.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/user.dart';
import 'package:escom_perdidos/data/repositories/report_repository.dart';
import 'package:escom_perdidos/data/services/media_service.dart';
import 'package:escom_perdidos/data/services/notification_service.dart';
import 'package:escom_perdidos/viewmodels/reports_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

class _Notifications extends NotificationService {
  int sent = 0;
  @override
  Future<void> show({required String title, required String body}) async {
    sent++;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    sent++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'guardar hallazgo conserva custodia, no publica muestras ni envía avisos',
    () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      await SeedData.ensure(db);
      final notifications = _Notifications();
      final repository = ReportRepository(db);
      final vm = ReportsViewModel(
        repository: repository,
        notifications: notifications,
        media: MediaService(),
      );
      addTearDown(vm.dispose);
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
      await vm.create(report, user);
      expect(
        (await repository.findById(report.id))!.custody,
        ItemCustody.prefecture,
      );
      expect(vm.mine(user.id).single.id, report.id);
      expect(await repository.fetchAll(), hasLength(7));
      expect(vm.communityFound, isEmpty);
      expect(notifications.sent, 0);
      await expectLater(
        vm.create(report.copyWith(type: ReportType.lost), user),
        throwsA(isA<AppException>()),
      );
      expect(await repository.fetchAll(), hasLength(7));
      await vm.update(report.copyWith(custody: ItemCustody.student));
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
