import 'package:flutter/foundation.dart';

import '../core/constants/escom.dart';
import '../core/errors/app_exception.dart';
import '../data/models/report.dart';
import '../data/models/report_filter.dart';
import '../data/models/user.dart';
import '../data/repositories/report_repository.dart';
import '../data/services/media_service.dart';
import '../data/services/notification_service.dart';

/// Lista de reportes, búsqueda/filtros y operaciones CRUD (RF2).
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({
    required ReportRepository repository,
    required NotificationService notifications,
    required MediaService media,
  }) : _repository = repository,
       _notifications = notifications,
       _media = media;

  final ReportRepository _repository;
  final NotificationService _notifications;
  final MediaService _media;

  List<Report> _all = const [];
  ReportFilter _filter = const ReportFilter();
  List<Report> _visible = const [];
  bool _loading = false;
  String? _error;

  ReportFilter get filter => _filter;
  List<Report> get visible => _visible;
  bool get loading => _loading;
  String? get error => _error;

  /// El catálogo público todavía no tiene fuente remota. Nunca se mezclan los
  /// registros de SQLite (incluidas muestras antiguas) con publicaciones reales.
  List<Report> get communityFound => const [];

  List<Report> mine(String userId) =>
      _all.where((r) => r.userId == userId).toList(growable: false);

  Report? byId(String id) {
    for (final report in _all) {
      if (report.id == id) return report;
    }
    return null;
  }

  int count(ReportType type) =>
      _all.where((r) => r.type == type && r.isActive).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await _repository.fetchAll();
      _applyFilter();
    } catch (e) {
      _error = userMessageFor(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateFilter(ReportFilter filter) {
    _filter = filter;
    _applyFilter();
    notifyListeners();
  }

  void search(String query) => updateFilter(_filter.copyWith(query: query));

  /// Guarda un hallazgo local. No publica, notifica ni busca coincidencias.
  Future<void> create(Report report, AppUser author) async {
    if (report.type != ReportType.found) {
      throw const AppException('Solo puedes registrar objetos encontrados.');
    }
    await _repository.create(report);
    await load();
  }

  Future<void> update(Report report, {String? replacedPhoto}) async {
    if (report.type != ReportType.found) {
      throw const AppException('Solo puedes registrar objetos encontrados.');
    }
    await _repository.update(report);
    if (replacedPhoto != null && replacedPhoto != report.photoPath) {
      await _media.deleteImage(replacedPhoto);
    }
    await load();
  }

  Future<void> toggleResolved(Report report) async {
    final resolved = report.isActive;
    await _repository.update(
      report.copyWith(
        status: resolved ? ReportStatus.resolved : ReportStatus.active,
        updatedAt: DateTime.now(),
      ),
    );
    if (resolved) {
      await _notifications.cancel(NotificationService.idFor(report.id));
    }
    await load();
  }

  Future<void> delete(Report report) async {
    await _repository.delete(report.id);
    await _notifications.cancel(NotificationService.idFor(report.id));
    await _media.deleteImage(report.photoPath);
    await load();
  }

  void _applyFilter() => _visible = _filter.apply(_all);
}
