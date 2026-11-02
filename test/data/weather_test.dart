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
    'apparent_temperature': 29.4,
    'is_day': 1,
    'weather_code': 2,
    'wind_speed_10m': 8.5,
    'wind_direction_10m': 63,
    'wind_gusts_10m': 21.2,
  },
  'hourly': {
    'time': ['2026-07-01T00:00', '2026-07-01T01:00', '2026-07-01T02:00'],
    'precipitation': [0.0, 1.2, 24.1],
    'temperature_2m': [18.5, 18.1, 17.6],
    'weather_code': [0, 61, 95],
    'precipitation_probability': [5, 40, 90],
    'wind_speed_10m': [3.2, 6.0, 18.4],
    'is_day': [0, 0, 1],
  },
  'daily': {
    'time': ['2026-07-01', '2026-07-02'],
    'weather_code': [99, 3],
    'temperature_2m_max': [28.0, 31.5],
    'temperature_2m_min': [19.2, 18.9],
    'precipitation_sum': [24.1, 0.0],
    'precipitation_probability_max': [83, 28],
    'sunrise': ['2026-07-01T05:25', '2026-07-02T05:26'],
    'sunset': ['2026-07-01T20:58', '2026-07-02T20:58'],
    'wind_speed_10m_max': [22.3, 9.1],
    'wind_gusts_10m_max': [48.6, 17.0],
    'precipitation_hours': [6.0, 0.0],
    'uv_index_max': [7.8, 8.1],
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
      expect(data.current.apparentTemperature, 29.4);
      expect(data.current.isDay, isTrue);
      expect(data.current.windDirection, 63);
      expect(data.current.windGusts, 21.2);
      expect(data.hourly.length, 3);
      expect(data.hourly[2].millimeters, 24.1);
      expect(data.hourlyTemperature.length, 3);
      expect(data.hourlyTemperature[0].celsius, 18.5);
      expect(data.hourlyForecast.length, 3);
      expect(data.hourlyForecast[2].weatherCode, 95);
      expect(data.hourlyForecast[2].precipitationProbability, 90);
      expect(data.hourlyForecast[2].windSpeed, 18.4);
      expect(data.hourlyForecast[0].isDay, isFalse);
      expect(data.hourlyForecast[2].isDay, isTrue);
      expect(data.daily.length, 2);
      expect(data.daily[0].weatherCode, 99);
      expect(data.daily[0].precipitationProbability, 83);
      expect(data.daily[0].sunrise, DateTime(2026, 7, 1, 5, 25));
      expect(data.daily[0].sunset, DateTime(2026, 7, 1, 20, 58));
      expect(data.daily[0].windGustsMax, 48.6);
      expect(data.daily[0].precipitationHours, 6.0);
      expect(data.daily[1].uvIndexMax, 8.1);
      expect(data.daily[1].precipitationSum, 0.0);
    });

    test('campi opzionali assenti -> valori nulli, non errori', () {
      final json = Map<String, dynamic>.from(_sampleJson);
      json['current'] = {
        'time': '2026-07-02T18:45',
        'temperature_2m': 20.0,
        'relative_humidity_2m': 50,
        'weather_code': 1,
        'wind_speed_10m': 4.0,
      };
      json['hourly'] = {
        'time': ['2026-07-01T00:00'],
        'precipitation': [0.0],
        'weather_code': [1],
      };
      json['daily'] = {
        'time': ['2026-07-01'],
        'weather_code': [1],
        'temperature_2m_max': [25.0],
        'temperature_2m_min': [15.0],
        'precipitation_sum': [0.0],
      };
      final data = WeatherData.fromApiJson(
        json,
        fetchedAtUtc: DateTime.utc(2026),
      )!;

      expect(data.current.apparentTemperature, isNull);
      expect(data.current.isDay, isTrue);
      expect(data.hourlyForecast.single.precipitationProbability, isNull);
      expect(data.hourlyForecast.single.isDay, isTrue);
      expect(data.daily.single.sunrise, isNull);
      expect(data.daily.single.precipitationProbability, isNull);
    });

    test('current mancante -> null', () {
      expect(
        WeatherData.fromApiJson(const {
          'hourly': {},
        }, fetchedAtUtc: DateTime.utc(2026)),
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
      expect(restored.current.apparentTemperature, 29.4);
      expect(restored.current.windDirection, 63);
      expect(restored.hourly.length, original.hourly.length);
      expect(
        restored.hourlyTemperature.length,
        original.hourlyTemperature.length,
      );
      expect(restored.hourlyTemperature[0].celsius, 18.5);
      expect(restored.hourlyForecast.length, 3);
      expect(restored.hourlyForecast[1].precipitationProbability, 40);
      expect(restored.hourlyForecast[0].isDay, isFalse);
      expect(restored.daily.length, original.daily.length);
      expect(
        restored.daily[0].precipitationProbability,
        original.daily[0].precipitationProbability,
      );
      expect(restored.daily[0].sunrise, original.daily[0].sunrise);
      expect(restored.daily[0].windGustsMax, 48.6);
      expect(restored.daily[1].uvIndexMax, 8.1);
    });
  });
}
