import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../data/models/app_notification.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/recovery_repository.dart';

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({required this.repository});
  final NotificationsRepository repository;
  String? _uid;
  int _session = 0, _revision = 0;
  bool _disposed = false, _refreshAgain = false;
  Future<void>? _loading;
  RecoverySubscription? _subscription;
  Timer? _poll;
  List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);
  NotificationPreferences preferences = const NotificationPreferences();
  String? error;
  bool loading = false,
      loadingMore = false,
      saving = false,
      connected = false,
      ready = false,
      hasMore = false;
  int unreadCount = 0;
  int get sessionRevision => _session;
  String? get userId => _uid;
  bool _valid(int session) => !_disposed && _uid != null && session == _session;

  void bindUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    final session = ++_session;
    _revision++;
    _loading = null;
    _refreshAgain = false;
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _items = [];
    preferences = const NotificationPreferences();
    unreadCount = 0;
    ready = connected = saving = loadingMore = hasMore = false;
    loading = uid != null;
    error = null;
    scheduleMicrotask(() {
      if (_disposed || session != _session) return;
      _notify();
      if (uid == null) return;
      unawaited(load());
      try {
        _subscription = repository.watch(
          changed: () {
            if (_valid(session)) unawaited(load());
          },
          connection: (value) {
            if (!_valid(session)) return;
            connected = value;
            _notify();
            if (value) unawaited(load());
          },
        );
      } catch (_) {
        connected = false;
      }
      _poll = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_valid(session)) unawaited(load());
      });
    });
  }

  /// Coalesce eventos sin perder una invalidación que llega durante una lectura.
  Future<void> load() {
    if (_uid == null || _disposed) return Future.value();
    if (_loading != null) {
      _refreshAgain = true;
      return _loading!;
    }
    final session = _session;
    final future = _drain(session).whenComplete(() {
      if (!_valid(session)) return;
      _loading = null;
    });
    _loading = future;
    return future;
  }

  Future<void> _drain(int session) async {
    do {
      _refreshAgain = false;
      await _refresh(session);
    } while (_valid(session) && _refreshAgain);
  }

  Future<void> _refresh(int session) async {
    final revision = ++_revision;
    loading = true;
    _notify();
    try {
      final oldest = _items.isEmpty ? null : _items.last;
      final refreshed = <AppNotification>[];
      var page = await repository.page();
      if (!_valid(session)) return;
      _checkRecipients(page);
      refreshed.addAll(page);
      // Rellena también el hueco de una desconexión con más de 50 eventos.
      while (oldest != null &&
          page.length == 50 &&
          _compare(page.last, oldest) < 0) {
        page = await repository.page(before: page.last);
        if (!_valid(session)) return;
        _checkRecipients(page);
        refreshed.addAll(page);
      }
      final count = await repository.unreadCount();
      if (!_valid(session)) return;
      final prefs = await repository.preferences();
      if (!_valid(session) || revision != _revision) return;
      _items = {for (final n in refreshed) n.id: n}.values.toList()
        ..sort(_compare);
      hasMore = page.length == 50;
      unreadCount = count;
      preferences = prefs;
      ready = true;
      error = null;
    } catch (e) {
      if (_valid(session)) error = userMessageFor(e);
    } finally {
      if (_valid(session)) {
        loading = false;
        _notify();
      }
    }
  }

  static int _compare(AppNotification a, AppNotification b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time == 0 ? b.id.compareTo(a.id) : time;
  }

  void _checkRecipients(List<AppNotification> page) {
    if (page.any((n) => n.recipientId != _uid)) {
      throw const PermissionException('No pudimos verificar tus avisos.');
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore || _items.isEmpty) return;
    final session = _session, revision = _revision;
    loadingMore = true;
    _notify();
    try {
      final page = await repository.page(before: _items.last);
      if (!_valid(session) || revision != _revision) return;
      _checkRecipients(page);
      _items = {
        for (final n in _items) n.id: n,
        for (final n in page) n.id: n,
      }.values.toList()..sort(_compare);
      hasMore = page.length == 50;
      error = null;
    } catch (e) {
      if (_valid(session)) error = userMessageFor(e);
    } finally {
      if (_valid(session)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  void assertSession(int session) {
    if (!_valid(session) || repository.currentUserId != _uid) {
      throw const AuthException('La sesión cambió. Abre de nuevo la pantalla.');
    }
  }

  Future<void> _write(Future<void> Function() action) async {
    final session = _session;
    assertSession(session);
    if (saving) {
      throw const AppException('Espera a que termine la operación actual.');
    }
    saving = true;
    _notify();
    try {
      await action();
      assertSession(session);
      // Una lectura anterior no debe sobrescribir una escritura confirmada.
      _revision++;
      await load();
      assertSession(session);
    } finally {
      if (_valid(session)) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> markRead(AppNotification item) {
    if (item.recipientId != _uid) {
      throw const PermissionException('Este aviso no pertenece a tu cuenta.');
    }
    return _write(() async {
      final session = _session;
      await repository.markRead(id: item.id);
      assertSession(session);
      _items = _items
          .map((n) => n.id == item.id ? n.asRead(DateTime.now().toUtc()) : n)
          .toList();
    });
  }

  Future<void> markAllRead() => _write(() async {
    final session = _session;
    final before = _items.isEmpty
        ? DateTime.now().toUtc()
        : _items.first.createdAt;
    await repository.markRead(before: before);
    assertSession(session);
    _items = _items
        .map(
          (n) => !n.createdAt.isAfter(before)
              ? n.asRead(DateTime.now().toUtc())
              : n,
        )
        .toList();
  });
  Future<void> savePreferences(NotificationPreferences value) =>
      _write(() async {
        final session = _session;
        final saved = await repository.savePreferences(value);
        assertSession(session);
        preferences = saved;
      });
  Future<void> completeTutorial() =>
      _write(() => repository.completeTutorial());
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    _items = [];
    super.dispose();
  }
}
