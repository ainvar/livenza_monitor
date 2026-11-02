import '../cache/station_history_cache.dart';
import '../datasources/station_history_datasource.dart';
import '../models/level_data.dart';

class StationHistoryResult {
  const StationHistoryResult({required this.data, required this.fromCache});

  final LevelData data;
  final bool fromCache;
}

class StationHistoryRepository {
  StationHistoryRepository({required this.datasource, required this.cache});

  final StationHistoryDatasource datasource;
  final StationHistoryCache cache;

  Future<StationHistoryResult> load(int stationId) async {
    late final LevelData data;
    try {
      data = LevelData(
        history: await datasource.fetchHistory(stationId),
        fetchedAtUtc: DateTime.now().toUtc(),
      );
    } catch (_) {
      // Un guasto della cache non deve nascondere l'errore della sorgente.
      LevelData? cached;
      try {
        cached = await cache.read(stationId);
      } catch (_) {
        cached = null;
      }
      if (cached != null && !cached.isEmpty) {
        return StationHistoryResult(data: cached, fromCache: true);
      }
      rethrow;
    }
    // Una risposta vuota resta vuota; non si presenta una vecchia misura
    // come attuale. La cache precedente resta utile in caso di rete assente.
    if (!data.isEmpty) {
      try {
        await cache.save(stationId, data);
      } catch (_) {
        // Il dato appena scaricato è utilizzabile anche senza persistenza.
      }
    }
    return StationHistoryResult(data: data, fromCache: false);
  }
}
