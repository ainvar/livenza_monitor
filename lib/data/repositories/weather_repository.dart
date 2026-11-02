import '../cache/weather_cache.dart';
import '../datasources/weather_datasource.dart';
import '../models/weather_data.dart';

/// Esito del caricamento meteo: dati + provenienza.
class WeatherResult {
  const WeatherResult({
    required this.data,
    required this.fromCache,
    this.isOfflineFallback = false,
  });

  final WeatherData data;
  final bool fromCache;
  final bool isOfflineFallback;
}

/// Forecast base indipendente dall'ensemble: può essere mostrato subito.
class WeatherRepository {
  WeatherRepository({required this.datasource, required this.cache});

  final WeatherDatasource datasource;
  final WeatherCache cache;
  static const maxAge = Duration(minutes: 15);
  Future<WeatherResult>? _pending;

  Future<WeatherResult> load({bool force = false}) =>
      _pending ??= _load(force: force).whenComplete(() => _pending = null);

  Future<WeatherResult> _load({required bool force}) async {
    WeatherData? cached;
    try {
      cached = await cache.read();
    } catch (_) {
      // Una cache non leggibile non impedisce il download.
    }
    if (!force && cached != null) {
      final age = DateTime.now().toUtc().difference(cached.fetchedAtUtc);
      if (!age.isNegative && age < maxAge) {
        return WeatherResult(data: cached, fromCache: true);
      }
    }
    try {
      final data = await datasource.fetchForecast();
      try {
        await cache.save(data);
      } catch (_) {
        // Restituisce comunque la previsione appena ricevuta.
      }
      return WeatherResult(data: data, fromCache: false);
    } catch (_) {
      if (cached != null) {
        return WeatherResult(
          data: cached,
          fromCache: true,
          isOfflineFallback: true,
        );
      }
      rethrow;
    }
  }
}
