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
  })  : _repository = repository,
        _notifications = notifications,
        _media = media;

  final ReportRepository _repository;
  final NotificationService _notifications;
  final MediaService _media;

  static const reminderDelay = Duration(days: 3);

  List<Report> _all = const [];
  ReportFilter _filter = const ReportFilter();
  List<Report> _visible = const [];
  bool _loading = false;
  String? _error;

  ReportFilter get filter => _filter;
  List<Report> get visible => _visible;
  bool get loading => _loading;
  String? get error => _error;

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

  /// Crea el reporte, avisa al usuario y busca posibles coincidencias.
  Future<void> create(Report report, AppUser author) async {
    await _repository.create(report);
    await load();
    if (!author.notificationsEnabled) return;

    await _notifications.show(
      title: 'Reporte publicado',
      body: '"${report.title}" ya es visible para la comunidad ESCOM.',
    );
    final matches = await _repository.findMatches(report);
    if (matches.isNotEmpty) {
      final first = matches.first;
      await _notifications.show(
        title: '¡Posible coincidencia!',
        body: matches.length == 1
            ? '"${first.title}" (${first.type.label.toLowerCase()}) en ${first.location}.'
            : 'Hay ${matches.length} reportes de ${report.category.label.toLowerCase()} que podrían ser tuyos.',
      );
    }
    if (report.type == ReportType.lost) {
      await _notifications.schedule(
        id: NotificationService.idFor(report.id),
        title: '¿Ya recuperaste tu objeto?',
        body: 'Si encontraste "${report.title}", márcalo como resuelto.',
        when: DateTime.now().add(reminderDelay),
      );
    }
  }

  Future<void> update(Report report, {String? replacedPhoto}) async {
    await _repository.update(report);
    if (replacedPhoto != null && replacedPhoto != report.photoPath) {
      await _media.deleteImage(replacedPhoto);
    }
    await load();
  }

  Future<void> toggleResolved(Report report) async {
    final resolved = report.isActive;
    await _repository.update(report.copyWith(
      status: resolved ? ReportStatus.resolved : ReportStatus.active,
      updatedAt: DateTime.now(),
    ));
    if (resolved) await _notifications.cancel(NotificationService.idFor(report.id));
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
