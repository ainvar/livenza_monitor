import '../cache/weather_cache.dart';
import '../datasources/weather_datasource.dart';
import '../models/weather_data.dart';

/// Esito del caricamento meteo: dati + provenienza.
class WeatherResult {
  const WeatherResult({required this.data, required this.fromCache});

  final WeatherData data;
  final bool fromCache;
}

/// Rete prima, cache come ripiego (come gli altri repository).
class WeatherRepository {
  WeatherRepository({required this.datasource, required this.cache});

  final WeatherDatasource datasource;
  final WeatherCache cache;

  Future<WeatherResult> load() async {
    try {
      final data = await datasource.fetchForecast();
      await cache.save(data);
      return WeatherResult(data: data, fromCache: false);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) {
        return WeatherResult(data: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
