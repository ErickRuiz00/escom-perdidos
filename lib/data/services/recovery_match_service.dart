import '../../core/constants/escom.dart';
import '../models/report.dart';

/// Punto de integración para un futuro origen compartido de objetos perdidos.
/// No mezcla registros SQLite heredados con identidades/catálogos de Supabase.
class RecoveryMatchService {
  RecoveryMatchService({this.lostPublications});
  final Future<List<Report>> Function()? lostPublications;
  final _dismissed = <String>{};
  String? _user;
  bool get available => lostPublications != null;
  void bindUser(String? uid) {
    if (_user != uid) {
      _user = uid;
      _dismissed.clear();
    }
  }

  void dismiss(String lostId, String foundId) =>
      _dismissed.add('$lostId/$foundId');
  Future<List<Report>> suggestions(Report found) async {
    final uid = _user;
    if (uid == null ||
        !available ||
        found.type != ReportType.found ||
        !found.isActive) {
      return [];
    }
    final lost = await lostPublications!();
    if (_user != uid) return [];
    int score(Report r) =>
        (r.location == found.location ? 2 : 0) +
        (r.eventDate.difference(found.eventDate).inDays.abs() <= 7 ? 1 : 0);
    return lost
        .where(
          (r) =>
              r.type == ReportType.lost &&
              r.isActive &&
              r.category == found.category &&
              r.userId == uid &&
              found.userId != uid &&
              !_dismissed.contains('${r.id}/${found.id}') &&
              r.eventDate.difference(found.eventDate).inDays.abs() <= 30,
        )
        .toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
  }
}
