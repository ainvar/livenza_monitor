import '../../core/config/app_config.dart';
import '../../domain/services/history_aggregator.dart';
import '../cache/history_cache.dart';
import '../datasources/history_datasource.dart';
import '../models/weather_history.dart';

/// Esito del caricamento dello storico.
class HistoryResult {
  const HistoryResult({required this.data, required this.fromCache});

  final WeatherHistory data;
  final bool fromCache;
}

/// A differenza degli altri repository è cache-first: il download è
/// grande (~500 KB) e lo storico cambia lentamente, quindi la cache
/// vale [AppConfig.historyMaxAge] prima di riscaricare.
class HistoryRepository {
  HistoryRepository({
    required this.datasource,
    required this.cache,
    required this.aggregator,
  });

  final HistoryDatasource datasource;
  final HistoryCache cache;
  final HistoryAggregator aggregator;

  Future<HistoryResult> load({bool force = false}) async {
    final cached = await cache.read();
    if (!force && cached != null) {
      final age = DateTime.now().toUtc().difference(cached.fetchedAtUtc);
      if (age < AppConfig.historyMaxAge) {
        return HistoryResult(data: cached, fromCache: true);
      }
    }
    try {
      final raw = await datasource.fetchDailySeries();
      final data = aggregator.aggregate(
        raw,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      await cache.save(data);
      return HistoryResult(data: data, fromCache: false);
    } catch (_) {
      if (cached != null) {
        return HistoryResult(data: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
