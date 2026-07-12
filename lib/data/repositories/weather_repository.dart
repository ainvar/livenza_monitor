import '../../domain/services/forecast_reliability.dart';
import '../cache/weather_cache.dart';
import '../datasources/ensemble_datasource.dart';
import '../datasources/weather_datasource.dart';
import '../models/weather_data.dart';

/// Esito del caricamento meteo: dati + provenienza.
class WeatherResult {
  const WeatherResult({required this.data, required this.fromCache});

  final WeatherData data;
  final bool fromCache;
}

/// Rete prima, cache come ripiego (come gli altri repository).
/// L'affidabilità (ensemble) è un arricchimento: se il suo download
/// fallisce, la previsione viene mostrata comunque.
class WeatherRepository {
  WeatherRepository({
    required this.datasource,
    required this.ensembleDatasource,
    required this.reliability,
    required this.cache,
  });

  final WeatherDatasource datasource;
  final EnsembleDatasource ensembleDatasource;
  final ForecastReliability reliability;
  final WeatherCache cache;

  Future<WeatherResult> load() async {
    try {
      var data = await datasource.fetchForecast();
      try {
        final ensemble = await ensembleDatasource.fetchHourlyPrecipitation();
        final result = reliability.compute(ensemble, now: data.current.time);
        data = data.withReliability(
          daily: result.daily,
          next48h: result.next48h,
        );
      } catch (_) {
        // Ensemble non disponibile: si mostra la previsione senza
        // percentuali di affidabilità.
      }
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
