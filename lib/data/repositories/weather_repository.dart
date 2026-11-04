import 'package:sqflite/sqflite.dart';

import '../../core/config/env.dart';
import '../../core/constants/escom.dart';
import '../../core/errors/app_exception.dart';
import '../local/app_database.dart';
import '../models/weather.dart';
import '../services/api_client.dart';

/// Clima en el campus con estrategia "red primero, caché como respaldo":
/// si no hay internet se muestra el último dato guardado en SQLite.
class WeatherRepository {
  WeatherRepository({required AppDatabase database, required ApiClient api})
      : _database = database,
        _api = api;

  final AppDatabase _database;
  final ApiClient _api;

  Future<Weather> current() async {
    try {
      final uri = Uri.parse(Env.weatherBaseUrl).replace(queryParameters: {
        'latitude': '${Escom.latitude}',
        'longitude': '${Escom.longitude}',
        'current': 'temperature_2m,weather_code,precipitation_probability',
        'timezone': Escom.timezone,
      });
      final weather = Weather.fromApi(await _api.getJson(uri));
      final db = await _database.database;
      await db.insert('weather_cache', weather.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      return weather;
    } on NetworkException {
      final cached = await _cached();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Weather?> _cached() async {
    final db = await _database.database;
    final rows = await db.query('weather_cache', where: 'id = 1');
    return rows.isEmpty ? null : Weather.fromMap(rows.first);
  }
}
