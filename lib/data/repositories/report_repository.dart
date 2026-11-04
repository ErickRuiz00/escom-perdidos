import 'package:sqflite/sqflite.dart';

import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../local/app_database.dart';
import '../models/report.dart';

/// Operaciones CRUD de reportes sobre SQLite (RF2).
class ReportRepository {
  ReportRepository(this._database);

  final AppDatabase _database;

  static const _select = '''
    SELECT r.*, u.name AS author_name
    FROM reports r JOIN users u ON u.id = r.user_id
  ''';

  Future<List<Report>> fetchAll() => _guard(() async {
        final db = await _database.database;
        final rows = await db.rawQuery('$_select ORDER BY r.created_at DESC');
        return rows.map(Report.fromMap).toList();
      });

  Future<Report?> findById(String id) => _guard(() async {
        final db = await _database.database;
        final rows = await db.rawQuery('$_select WHERE r.id = ? LIMIT 1', [id]);
        return rows.isEmpty ? null : Report.fromMap(rows.first);
      });

  Future<void> create(Report report) => _guard(() async {
        final db = await _database.database;
        await db.insert('reports', report.toMap());
      });

  Future<void> update(Report report) => _guard(() async {
        final db = await _database.database;
        await db.update('reports', report.toMap(),
            where: 'id = ?', whereArgs: [report.id]);
      });

  Future<void> delete(String id) => _guard(() async {
        final db = await _database.database;
        await db.delete('reports', where: 'id = ?', whereArgs: [id]);
      });

  /// Reportes activos del tipo contrario y misma categoría de otros usuarios:
  /// si alguien encontró unos audífonos, avisa a quien reportó haberlos perdido.
  Future<List<Report>> findMatches(Report report) => _guard(() async {
        final db = await _database.database;
        final opposite =
            report.type == ReportType.lost ? ReportType.found : ReportType.lost;
        final rows = await db.rawQuery(
          '$_select WHERE r.type = ? AND r.category = ? AND r.status = ? '
          'AND r.user_id != ? ORDER BY r.created_at DESC',
          [opposite.name, report.category.name, ReportStatus.active.name, report.userId],
        );
        return rows.map(Report.fromMap).toList();
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw StorageException('No se pudo acceder a los reportes guardados.', cause: e);
    }
  }
}
