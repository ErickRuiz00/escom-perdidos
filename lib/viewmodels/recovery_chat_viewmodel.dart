import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';
import '../data/models/recovery.dart';
import '../data/repositories/recovery_repository.dart';
import 'recovery_viewmodel.dart';

class PendingRecoveryMessage {
  PendingRecoveryMessage({required this.id, required this.body});
  final String id, body;
  bool sending = false;
  String? error;
}

class RecoveryChatViewModel extends ChangeNotifier {
  RecoveryChatViewModel({required this.recovery, required this.conversation})
    : _session = recovery.sessionRevision,
      userId = recovery.userId {
    recovery.addListener(_changed);
  }
  final RecoveryViewModel recovery;
  final RecoveryConversation conversation;
  final String? userId;
  final int _session;
  RecoveryRepository get _repository => recovery.repository;
  List<RecoveryMessage> _messages = [];
  RecoveryMessage? _latestFetched;
  final _pending = <String, PendingRecoveryMessage>{};
  List<RecoveryMessage> get messages => List.unmodifiable(_messages);
  List<PendingRecoveryMessage> get pending =>
      List.unmodifiable(_pending.values);
  bool _disposed = false, _ended = false, _fetching = false, _started = false;
  bool loading = false, connected = false, hasOlder = true;
  String? error;
  Timer? _poll;
  RecoverySubscription? _subscription;
  bool get active {
    final current = recovery.conversation(conversation.requestId);
    return !_ended &&
        recovery.sessionRevision == _session &&
        current != null &&
        current.id == conversation.id &&
        current.closedAt == null &&
        recovery.byId(conversation.requestId)?.status ==
            RecoveryStatus.accepted;
  }

  bool get sending => _pending.values.any((m) => m.sending);
  bool get sessionEnded => _ended;
  bool get _valid =>
      !_disposed && !_ended && recovery.sessionRevision == _session;
  void _changed() {
    if (_disposed) return;
    if (recovery.sessionRevision != _session) {
      _ended = true;
      _clear();
    } else if (!active) {
      _messages = [];
      _latestFetched = null;
      _pending.clear();
      _stop();
    } else if (!_started) {
      unawaited(start());
    }
    _notify();
  }

  Future<void> start() async {
    if (!_valid || !active || _started) return;
    _started = true;
    try {
      _subscription = _repository.watch(
        conversationId: conversation.id,
        changed: () {
          if (_valid) unawaited(load());
        },
        connection: (ok) {
          if (!_valid) return;
          connected = ok;
          _notify();
          if (ok) unawaited(load());
        },
      );
    } catch (_) {
      connected = false;
    }
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_valid && active) {
        unawaited(recovery.load());
        unawaited(load());
      }
    });
    await load();
  }

  Future<void> load({bool older = false}) async {
    if (!_valid || !active || _fetching) return;
    _fetching = true;
    loading = true;
    _notify();
    try {
      final after = !older ? _latestFetched : null;
      final page = await _repository.messages(
        conversation.id,
        before: older && _messages.isNotEmpty ? _messages.first : null,
        after: after,
      );
      if (!_valid || !active) return;
      final all = {
        for (final m in _messages) m.id: m,
        for (final m in page) m.id: m,
      };
      var newest = page.isNotEmpty ? page.last : _latestFetched;
      // Recorre todos los mensajes nuevos tras una desconexión prolongada.
      if (after != null) {
        var batch = page;
        while (batch.length == 50) {
          batch = await _repository.messages(
            conversation.id,
            after: batch.last,
          );
          if (!_valid || !active) return;
          for (final message in batch) {
            all[message.id] = message;
          }
          if (batch.isNotEmpty) newest = batch.last;
        }
      }
      _messages = all.values.toList()
        ..sort((a, b) {
          final result = a.createdAt.compareTo(b.createdAt);
          return result == 0 ? a.id.compareTo(b.id) : result;
        });
      if (!older) _latestFetched = newest;
      for (final m in all.values) {
        _pending.remove(m.id);
      }
      if (older || after == null) hasOlder = page.length == 50;
      error = null;
    } catch (e) {
      if (_valid) error = userMessageFor(e);
    } finally {
      _fetching = false;
      if (_valid) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> send(String body) async {
    if (!_valid || !active) {
      throw const PermissionException('La conversación ya no está activa.');
    }
    final text = body.trim();
    if (text.isEmpty || text.length > 2000) {
      throw const AppException('Escribe un mensaje de 1 a 2000 caracteres.');
    }
    if (sending) {
      throw const AppException('Espera a que termine el mensaje actual.');
    }
    final message = PendingRecoveryMessage(id: const Uuid().v4(), body: text);
    _pending[message.id] = message;
    await retry(message.id);
  }

  Future<void> retry(String id) async {
    final message = _pending[id];
    if (message == null || message.sending || !_valid || !active) return;
    message.sending = true;
    message.error = null;
    _notify();
    try {
      final saved = await _repository.send(
        id: id,
        conversationId: conversation.id,
        body: message.body,
      );
      if (!_valid || !active) return;
      _pending.remove(id);
      _messages = {
        for (final m in _messages) m.id: m,
        saved.id: saved,
      }.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      if (_valid && active) message.error = userMessageFor(e);
    } finally {
      if (_valid) {
        message.sending = false;
        _notify();
      }
    }
  }

  void _stop() {
    _started = false;
    _poll?.cancel();
    _poll = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _clear() {
    _stop();
    _messages = [];
    _latestFetched = null;
    _pending.clear();
    error = null;
    connected = false;
    loading = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    recovery.removeListener(_changed);
    _clear();
    super.dispose();
  }
}
