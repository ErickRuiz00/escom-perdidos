import 'dart:async';
import 'package:flutter/foundation.dart';

/// Estado temporal del recorrido; se descarta al cambiar de cuenta.
class TutorialViewModel extends ChangeNotifier {
  String? _uid;
  int? _step;
  int _revision = 0;
  bool _disposed = false;
  bool get active => _step != null;
  int get step => _step ?? 0;
  int get revision => _revision;

  void bindUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _step = null;
    final revision = ++_revision;
    scheduleMicrotask(() {
      if (!_disposed && revision == _revision) notifyListeners();
    });
  }

  void start() {
    if (_uid == null) return;
    _revision++;
    _step = 0;
    notifyListeners();
  }

  void goTo(int step) {
    if (!active || step < 0 || step >= 5 || _step == step) return;
    _step = step;
    notifyListeners();
  }

  void stop() {
    if (!active) return;
    _step = null;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
