import '../../core/constants/escom.dart';
import 'report.dart';

enum ReportSort {
  newest('Más recientes'),
  oldest('Más antiguos'),
  eventDate('Fecha del suceso'),
  title('Nombre (A-Z)');

  const ReportSort(this.label);
  final String label;
}

/// Criterios de búsqueda, filtrado y orden de la lista de reportes (RF2).
class ReportFilter {
  const ReportFilter({
    this.query = '',
    this.type,
    this.category,
    this.status,
    this.location,
    this.sort = ReportSort.newest,
  });

  final String query;
  final ReportType? type;
  final ItemCategory? category;
  final ReportStatus? status;
  final String? location;
  final ReportSort sort;

  /// Número de filtros activos (sin contar búsqueda ni orden), para el badge.
  int get activeCount =>
      [type, category, status, location].where((f) => f != null).length;

  ReportFilter copyWith({
    String? query,
    ReportType? Function()? type,
    ItemCategory? Function()? category,
    ReportStatus? Function()? status,
    String? Function()? location,
    ReportSort? sort,
  }) {
    return ReportFilter(
      query: query ?? this.query,
      type: type != null ? type() : this.type,
      category: category != null ? category() : this.category,
      status: status != null ? status() : this.status,
      location: location != null ? location() : this.location,
      sort: sort ?? this.sort,
    );
  }

  ReportFilter clearFilters() => ReportFilter(query: query, sort: sort);

  /// Aplica el filtro en memoria. Es puro, así que se prueba con unit tests.
  List<Report> apply(Iterable<Report> reports) {
    final words = _normalize(query).split(' ').where((w) => w.isNotEmpty).toList();
    final result = reports.where((r) {
      if (type != null && r.type != type) return false;
      if (category != null && r.category != category) return false;
      if (status != null && r.status != status) return false;
      if (location != null && r.location != location) return false;
      if (words.isEmpty) return true;
      final haystack = _normalize(
        '${r.title} ${r.description} ${r.location} ${r.category.label}',
      );
      return words.every(haystack.contains);
    }).toList();

    result.sort(switch (sort) {
      ReportSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      ReportSort.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
      ReportSort.eventDate => (a, b) => b.eventDate.compareTo(a.eventDate),
      ReportSort.title => (a, b) =>
          _normalize(a.title).compareTo(_normalize(b.title)),
    });
    return result;
  }

  static const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

  static String _normalize(String text) {
    var lower = text.toLowerCase();
    _accents.forEach((k, v) => lower = lower.replaceAll(k, v));
    return lower.trim();
  }
}
