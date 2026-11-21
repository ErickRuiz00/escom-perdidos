import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../data/models/recovery.dart';
import '../data/repositories/recovery_repository.dart';

class RecoveryViewModel extends ChangeNotifier {
  RecoveryViewModel({required this.repository, this.onItemChanged});
  final RecoveryRepository repository;
  final Future<void> Function()? onItemChanged;
  String? _uid;
  int _session = 0, _read = 0;
  int? _pendingRead;
  bool _disposed = false, loading = false, connected = false;
  String? error;
  List<RecoveryRequest> _requests = [];
  List<RecoveryConversation> _conversations = [];
  List<String> _blocked = [];
  final _busy = <String>{};
  RecoverySubscription? _subscription;
  Timer? _poll;
  String? get userId => _uid;
  int get sessionRevision => _session;
  List<RecoveryRequest> get requests => List.unmodifiable(_requests);
  List<RecoveryConversation> get conversations =>
      List.unmodifiable(_conversations);
  List<String> get blocked => List.unmodifiable(_blocked);
  int get incomingPending => _requests
      .where((r) => r.finderId == _uid && r.status == RecoveryStatus.pending)
      .length;
  bool busy(String id) => _busy.contains(id);
  RecoveryRequest? byId(String id) {
    for (final r in _requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  RecoveryConversation? conversation(String requestId) {
    for (final c in _conversations) {
      if (c.requestId == requestId) return c;
    }
    return null;
  }

  void bindUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _session++;
    _read++;
    _pendingRead = null;
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _requests = [];
    _conversations = [];
    _blocked = [];
    _busy.clear();
    error = null;
    connected = false;
    loading = uid != null;
    final session = _session;
    scheduleMicrotask(() {
      if (_disposed || session != _session) return;
      notifyListeners();
      if (uid == null) return;
      unawaited(load());
      try {
        _subscription = repository.watch(
          changed: () {
            if (_valid(session)) unawaited(load());
          },
          connection: (ok) {
            if (!_valid(session)) return;
            connected = ok;
            _notify();
            if (ok) unawaited(load());
          },
        );
      } catch (_) {
        connected = false;
      }
      _poll = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_valid(session)) unawaited(load());
      });
    });
  }

  bool _valid(int session) => !_disposed && _uid != null && session == _session;
  void assertSession(int session) {
    if (!_valid(session)) {
      throw const AuthException('La sesión cambió. Abre de nuevo la pantalla.');
    }
  }

  Future<void> load() async {
    if (_uid == null || _disposed || _pendingRead != null) return;
    final session = _session, read = ++_read;
    _pendingRead = read;
    loading = true;
    _notify();
    try {
      final requests = await repository.requests();
      final conversations = await repository.conversations();
      final blocked = await repository.blockedUsers();
      if (!_valid(session) || read != _read) return;
      if (requests.any((r) => r.finderId != _uid && r.requesterId != _uid)) {
        throw const PermissionException(
          'No pudimos verificar tus solicitudes.',
        );
      }
      _requests = requests;
      _conversations = conversations;
      _blocked = blocked;
      error = null;
    } catch (e) {
      if (_valid(session) && read == _read) error = userMessageFor(e);
    } finally {
      if (_pendingRead == read) _pendingRead = null;
      if (_valid(session) && read == _read) {
        loading = false;
        _notify();
      }
    }
  }

  Future<T> _write<T>(String key, Future<T> Function() action) async {
    final session = _session;
    assertSession(session);
    if (!_busy.add(key)) {
      throw const AppException('Espera a que termine la operación actual.');
    }
    _notify();
    try {
      final result = await action();
      assertSession(session);
      // Invalida lecturas previas a la escritura confirmada.
      _read++;
      _pendingRead = null;
      if (result is RecoveryRequest) {
        _requests = [result, ..._requests.where((r) => r.id != result.id)]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _notify();
      await load();
      assertSession(session);
      return result;
    } finally {
      if (_valid(session)) {
        _busy.remove(key);
        _notify();
      }
    }
  }

  Future<RecoveryRequest> create({
    required String id,
    required String itemId,
    required String evidence,
    required int session,
  }) {
    assertSession(session);
    return _write(
      id,
      () => repository.create(id: id, itemId: itemId, evidence: evidence),
    );
  }

  Future<void> act(
    RecoveryRequest request,
    String action, {
    String? point,
    DateTime? at,
  }) async {
    if (request.finderId != _uid && request.requesterId != _uid) {
      throw const PermissionException(
        'Solicitud no disponible para tu cuenta.',
      );
    }
    final saved = await _write(
      request.id,
      () => repository.act(request, action, point: point, at: at),
    );
    if (saved.closeReason == 'returned') await onItemChanged?.call();
  }

  Future<void> block(RecoveryRequest request, bool blocked) =>
      _write(request.id, () => repository.block(request.peer(_uid!), blocked));
  Future<void> report(
    RecoveryRequest request, {
    required String id,
    required String reason,
  }) => _write(
    request.id,
    () => repository.report(id: id, requestId: request.id, reason: reason),
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    _requests = [];
    _conversations = [];
    _blocked = [];
    super.dispose();
  }
}
