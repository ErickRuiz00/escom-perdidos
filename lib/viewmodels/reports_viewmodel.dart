import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/models/report.dart';
import '../data/models/user.dart';
import '../data/repositories/found_items_repository.dart';

/// Catálogo remoto y publicaciones propias, aislados por sesión.
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({required FoundItemsRepository repository})
    : _repository = repository;
  final FoundItemsRepository _repository;
  List<Report> _community = const [];
  List<Report> _mine = const [];
  final _details = <String, Report>{};
  final _photoUrls = <String, ({String url, DateTime expires})>{};
  String? _userId;
  int _session = 0;
  int _request = 0;
  bool _disposed = false;
  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  int get sessionRevision => _session;
  String? get error => _error;
  List<Report> get communityFound => List.unmodifiable(_community);
  List<Report> mine(String uid) =>
      uid == _userId ? List.unmodifiable(_mine) : const [];
  Report? byId(String id) => _details[id];

  void bindUser(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _session++;
    _request++;
    _community = const [];
    _mine = const [];
    _details.clear();
    _photoUrls.clear();
    _loading = uid != null;
    _error = null;
    final session = _session;
    scheduleMicrotask(() {
      if (_disposed || session != _session) return;
      notifyListeners();
      if (uid != null) unawaited(load());
    });
  }

  Future<void> load() async {
    if (_userId == null) return;
    final session = _session;
    final request = ++_request;
    _loading = true;
    _error = null;
    _notify();
    try {
      final lists = await Future.wait([
        _repository.fetchAll(),
        _repository.fetchMine(),
      ]);
      if (_disposed || session != _session || request != _request) return;
      if (lists[1].any((r) => r.userId != _userId)) {
        throw const PermissionException(
          'No pudimos verificar tus publicaciones.',
        );
      }
      _community = lists[0].where((r) => r.isActive).toList();
      _mine = lists[1];
      _details
        ..clear()
        ..addEntries([..._community, ..._mine].map((r) => MapEntry(r.id, r)));
    } catch (e) {
      if (!_disposed && session == _session && request == _request) {
        _error = userMessageFor(e);
      }
    } finally {
      if (!_disposed && session == _session && request == _request) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<Report?> loadDetail(String id) async {
    final session = _session;
    final report = await _repository.findById(id);
    _assertSession(session);
    if (report == null) {
      _details.remove(id);
      _community = _community.where((r) => r.id != id).toList();
    } else {
      _store(report);
    }
    _notify();
    return report;
  }

  Future<Report> create(Report report, AppUser author) async {
    final session = _session;
    if (author.id != _userId || report.userId != _userId) {
      throw const PermissionException(
        'La sesión cambió. Inicia sesión de nuevo.',
      );
    }
    final saved = await _repository.create(report);
    _assertSession(session);
    _store(saved);
    return saved;
  }

  Future<Report> update(
    Report report, {
    required DateTime expectedUpdatedAt,
  }) async {
    final session = _session;
    final saved = await _repository.update(
      report,
      expectedUpdatedAt: expectedUpdatedAt,
    );
    _assertSession(session);
    _store(saved);
    return saved;
  }

  Future<void> withdraw(Report report) async {
    final session = _session;
    final saved = await _repository.withdraw(report);
    _assertSession(session);
    _store(saved);
  }

  void _store(Report report) {
    _request++;
    _loading = false;
    _error = null;
    _details[report.id] = report;
    _mine = [
      if (report.userId == _userId) report,
      ..._mine.where((r) => r.id != report.id),
    ];
    _community = [
      if (report.isActive) report,
      ..._community.where((r) => r.id != report.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notify();
  }

  Future<String> photoUrl(String path, {bool refresh = false}) async {
    final cached = _photoUrls[path];
    if (!refresh && cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    final session = _session;
    final url = await _repository.signedPhotoUrl(path);
    _assertSession(session);
    _photoUrls[path] = (
      url: url,
      expires: DateTime.now().add(const Duration(seconds: 100)),
    );
    return url;
  }

  void _assertSession(int session) {
    if (_disposed || _userId == null || session != _session) {
      throw const AuthException('La sesión cambió. Abre de nuevo la pantalla.');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _photoUrls.clear();
    super.dispose();
  }
}
