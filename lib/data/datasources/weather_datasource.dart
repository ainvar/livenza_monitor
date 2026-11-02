import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/weather_data.dart';
import '../models/weather_location.dart';
import 'level_datasource.dart';

/// Sorgente delle previsioni meteo.
abstract interface class WeatherDatasource {
  Future<WeatherData> fetchForecast();
}

/// Implementazione su Open-Meteo (https://open-meteo.com), gratuita
/// e senza chiave API.
class OpenMeteoWeatherDatasource implements WeatherDatasource {
  OpenMeteoWeatherDatasource(
    this._client, {
    this.location = WeatherLocation.sacile,
  });

  final http.Client _client;
  final WeatherLocation location;

  @override
  Future<WeatherData> fetchForecast() async {
    final uri = Uri.parse(AppConfig.openMeteoBaseUrl).replace(
      queryParameters: {
        'latitude': '${location.lat}',
        'longitude': '${location.lon}',
        // Orari nel fuso del bacino, coerenti per grafici e giorni.
        'timezone': 'Europe/Rome',
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,'
            'is_day,weather_code,wind_speed_10m,wind_direction_10m,'
            'wind_gusts_10m',
        'hourly':
            'precipitation,temperature_2m,weather_code,'
            'precipitation_probability,wind_speed_10m,is_day',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_sum,precipitation_probability_max,'
            'sunrise,sunset,wind_speed_10m_max,wind_gusts_10m_max,'
            'precipitation_hours,uv_index_max',
        // Stima del modello nelle ore precedenti, non misura pluviometrica.
        'past_days': '1',
        'forecast_days': '7',
      },
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConfig.httpTimeout);

    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LevelDatasourceException('Risposta API non valida');
    }

    final data = WeatherData.fromApiJson(
      body,
      fetchedAtUtc: DateTime.now().toUtc(),
      locationId: location.id,
    );
    if (data == null) {
      throw const LevelDatasourceException('Dati meteo non interpretabili');
    }
    return data;
  }
}
