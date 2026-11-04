import 'package:escom_perdidos/core/constants/escom.dart';
import 'package:escom_perdidos/data/models/report.dart';
import 'package:escom_perdidos/data/models/report_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Report _report(
  String id,
  String title, {
  ReportType type = ReportType.lost,
  ItemCategory category = ItemCategory.other,
  ReportStatus status = ReportStatus.active,
  String location = 'Biblioteca',
  int daysAgo = 0,
}) {
  final date = DateTime(2026, 10, 20).subtract(Duration(days: daysAgo));
  return Report(
    id: id,
    userId: 'u',
    type: type,
    title: title,
    description: 'Descripción de $title',
    category: category,
    location: location,
    eventDate: date,
    status: status,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final reports = [
    _report('1', 'Audífonos blancos', category: ItemCategory.electronics, daysAgo: 2),
    _report('2', 'Credencial IPN', type: ReportType.found,
        category: ItemCategory.documents, location: 'Cafetería', daysAgo: 0),
    _report('3', 'Calculadora Casio', category: ItemCategory.supplies,
        status: ReportStatus.resolved, location: 'Edificio 2', daysAgo: 5),
  ];

  test('sin filtros devuelve todo, más recientes primero', () {
    final result = const ReportFilter().apply(reports);
    expect(result.map((r) => r.id), ['2', '1', '3']);
  });

  test('búsqueda ignora mayúsculas y acentos', () {
    expect(const ReportFilter(query: 'AUDIFONOS').apply(reports).single.id, '1');
    expect(const ReportFilter(query: 'cafeteria').apply(reports).single.id, '2');
  });

  test('búsqueda con varias palabras exige todas', () {
    expect(const ReportFilter(query: 'credencial ipn').apply(reports), hasLength(1));
    expect(const ReportFilter(query: 'credencial casio').apply(reports), isEmpty);
  });

  test('filtra por tipo, categoría, estado y lugar', () {
    expect(const ReportFilter(type: ReportType.found).apply(reports).single.id, '2');
    expect(const ReportFilter(category: ItemCategory.supplies).apply(reports).single.id, '3');
    expect(const ReportFilter(status: ReportStatus.active).apply(reports), hasLength(2));
    expect(const ReportFilter(location: 'Edificio 2').apply(reports).single.id, '3');
  });

  test('ordena por nombre y por antigüedad', () {
    expect(const ReportFilter(sort: ReportSort.title).apply(reports).map((r) => r.id),
        ['1', '3', '2']);
    expect(const ReportFilter(sort: ReportSort.oldest).apply(reports).first.id, '3');
  });

  test('copyWith permite quitar un filtro y activeCount lo refleja', () {
    const filter = ReportFilter(type: ReportType.lost, category: ItemCategory.keys);
    expect(filter.activeCount, 2);
    final cleared = filter.copyWith(type: () => null);
    expect(cleared.type, isNull);
    expect(cleared.activeCount, 1);
    expect(filter.clearFilters().activeCount, 0);
  });
}
