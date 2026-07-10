import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/models/weather_data.dart';

/// Payload ridotto ma nella forma reale dell'API Open-Meteo.
final _sampleJson = <String, dynamic>{
  'latitude': 45.95,
  'longitude': 12.5,
  'current': {
    'time': '2026-07-02T18:45',
    'interval': 900,
    'temperature_2m': 31.1,
    'relative_humidity_2m': 34,
    'weather_code': 2,
    'wind_speed_10m': 8.5,
  },
  'hourly': {
    'time': ['2026-07-01T00:00', '2026-07-01T01:00', '2026-07-01T02:00'],
    'precipitation': [0.0, 1.2, 24.1],
  },
  'daily': {
    'time': ['2026-07-01', '2026-07-02'],
    'weather_code': [99, 3],
    'temperature_2m_max': [28.0, 31.5],
    'temperature_2m_min': [19.2, 18.9],
    'precipitation_sum': [24.1, 0.0],
    'precipitation_probability_max': [83, 28],
  },
};

void main() {
  group('WeatherData.fromApiJson', () {
    test('parsa il payload reale', () {
      final data = WeatherData.fromApiJson(
        _sampleJson,
        fetchedAtUtc: DateTime.utc(2026, 7, 2, 17),
      );

      expect(data, isNotNull);
      expect(data!.current.temperature, 31.1);
      expect(data.current.weatherCode, 2);
      expect(data.hourly.length, 3);
      expect(data.hourly[2].millimeters, 24.1);
      expect(data.daily.length, 2);
      expect(data.daily[0].weatherCode, 99);
      expect(data.daily[0].precipitationProbability, 83);
      expect(data.daily[1].precipitationSum, 0.0);
    });

    test('current mancante -> null', () {
      expect(
        WeatherData.fromApiJson(const {'hourly': {}},
            fetchedAtUtc: DateTime.utc(2026)),
        isNull,
      );
    });

    test('liste di lunghezza diversa -> tronca senza errori', () {
      final json = Map<String, dynamic>.from(_sampleJson);
      json['hourly'] = {
        'time': ['2026-07-01T00:00', '2026-07-01T01:00'],
        'precipitation': [0.5],
      };
      final data = WeatherData.fromApiJson(
        json,
        fetchedAtUtc: DateTime.utc(2026),
      );
      expect(data!.hourly.length, 1);
    });
  });

  group('WeatherData cache round-trip', () {
    test('serializza e riparsa senza perdite', () {
      final original = WeatherData.fromApiJson(
        _sampleJson,
        fetchedAtUtc: DateTime.utc(2026, 7, 2, 17),
      )!;

      final restored = WeatherData.fromCacheJson(original.toCacheJson());

      expect(restored, isNotNull);
      expect(restored!.fetchedAtUtc, original.fetchedAtUtc);
      expect(restored.current.temperature, original.current.temperature);
      expect(restored.hourly.length, original.hourly.length);
      expect(restored.daily.length, original.daily.length);
      expect(
        restored.daily[0].precipitationProbability,
        original.daily[0].precipitationProbability,
      );
    });
  });
}
