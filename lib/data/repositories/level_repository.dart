import '../../core/config/app_config.dart';
import '../cache/level_cache.dart';
import '../datasources/level_datasource.dart';
import '../models/level_data.dart';

/// Esito del caricamento: dati + indicazione se provengono dalla cache.
class LevelResult {
  const LevelResult({required this.data, required this.fromCache});

  final LevelData data;

  /// True se la rete non era raggiungibile e i dati vengono dalla cache.
  final bool fromCache;
}

/// Orchestrazione tra rete e cache: prova la rete, in caso di errore
/// ripiega sugli ultimi dati salvati.
class LevelRepository {
  LevelRepository({required this.datasource, required this.cache});

  final LevelDatasource datasource;
  final LevelCache cache;

  Future<LevelResult> load() async {
    try {
      final history = await datasource.fetchHistory(
        window: AppConfig.historyWindow,
      );
      final data = LevelData(
        history: history,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      await cache.save(data);
      return LevelResult(data: data, fromCache: false);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null && !cached.isEmpty) {
        return LevelResult(data: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
