import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/weather_data.dart';
import 'level_datasource.dart';

/// Sorgente delle previsioni meteo.
abstract interface class WeatherDatasource {
  Future<WeatherData> fetchForecast();
}

/// Implementazione su Open-Meteo (https://open-meteo.com), gratuita
/// e senza chiave API.
class OpenMeteoWeatherDatasource implements WeatherDatasource {
  OpenMeteoWeatherDatasource(this._client);

  final http.Client _client;

  @override
  Future<WeatherData> fetchForecast() async {
    final uri = Uri.parse(AppConfig.openMeteoBaseUrl).replace(
      queryParameters: {
        'latitude': '${AppConfig.sacileLat}',
        'longitude': '${AppConfig.sacileLon}',
        // Orari nel fuso del bacino, coerenti per grafici e giorni.
        'timezone': 'Europe/Rome',
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'hourly': 'precipitation,temperature_2m',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_sum,precipitation_probability_max',
        // Pioggia già caduta: utile per valutare il rischio di piena.
        'past_days': '1',
        'forecast_days': '7',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(AppConfig.httpTimeout);

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
    );
    if (data == null) {
      throw const LevelDatasourceException('Dati meteo non interpretabili');
    }
    return data;
  }
}
