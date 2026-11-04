/// Clima actual en el campus (Open-Meteo).
class Weather {
  const Weather({
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final double temperature;
  final int weatherCode;
  final int precipitationProbability;
  final DateTime fetchedAt;
  final bool fromCache;

  bool get rainLikely => precipitationProbability >= 50 || weatherCode >= 51;

  /// Descripción según los códigos WMO que usa Open-Meteo.
  String get description {
    if (weatherCode == 0) return 'Despejado';
    if (weatherCode <= 3) return 'Parcialmente nublado';
    if (weatherCode <= 48) return 'Neblina';
    if (weatherCode <= 67) return 'Lluvia';
    if (weatherCode <= 77) return 'Granizo';
    if (weatherCode <= 82) return 'Chubascos';
    return 'Tormenta';
  }

  String get tip => rainLikely
      ? 'Probable lluvia: revisa que no olvides tu paraguas en el salón.'
      : 'Buen día para buscar en canchas y explanada.';

  factory Weather.fromApi(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    return Weather(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      precipitationProbability:
          (current['precipitation_probability'] as num? ?? 0).toInt(),
      fetchedAt: DateTime.now(),
    );
  }

  factory Weather.fromMap(Map<String, Object?> map) => Weather(
        temperature: (map['temperature'] as num).toDouble(),
        weatherCode: map['weather_code'] as int,
        precipitationProbability: map['precipitation_probability'] as int,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(map['fetched_at'] as int),
        fromCache: true,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'temperature': temperature,
        'weather_code': weatherCode,
        'precipitation_probability': precipitationProbability,
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
      };
}
