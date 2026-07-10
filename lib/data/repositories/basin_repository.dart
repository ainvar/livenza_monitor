import '../cache/basin_cache.dart';
import '../datasources/basin_datasource.dart';
import '../models/basin_reading.dart';

/// Esito del caricamento del bacino: dati + provenienza.
class BasinResult {
  const BasinResult({required this.data, required this.fromCache});

  final BasinData data;
  final bool fromCache;
}

/// Come LevelRepository: rete prima, cache come ripiego.
class BasinRepository {
  BasinRepository({required this.datasource, required this.cache});

  final BasinDatasource datasource;
  final BasinCache cache;

  Future<BasinResult> load() async {
    try {
      final readings = await datasource.fetchLatestReadings();
      final data = BasinData(
        readings: readings,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      await cache.save(data);
      return BasinResult(data: data, fromCache: false);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null && !cached.isEmpty) {
        return BasinResult(data: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
