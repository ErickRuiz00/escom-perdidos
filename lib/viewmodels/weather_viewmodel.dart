import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/models/weather.dart';
import '../data/repositories/weather_repository.dart';

class WeatherViewModel extends ChangeNotifier {
  WeatherViewModel(this._repository);

  final WeatherRepository _repository;

  Weather? _weather;
  bool _loading = false;
  String? _error;

  Weather? get weather => _weather;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _weather = await _repository.current();
    } catch (e) {
      _error = userMessageFor(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
