import '../../core/config/app_config.dart';
import '../cache/level_cache.dart';
import '../datasources/level_datasource.dart';
import '../models/level_data.dart';

/// Esito del caricamento: dati + indicazione se provengono dalla cache.
class LevelResult {
  const LevelResult({required this.data, required this.fromCache});

  final LevelData data;

  /// True se si mostrano gli ultimi dati salvati sul dispositivo.
  final bool fromCache;
}

/// Orchestrazione tra rete e cache: prova la rete, in caso di errore
/// ripiega sugli ultimi dati salvati.
class LevelRepository {
  LevelRepository({required this.datasource, required this.cache});

  final LevelDatasource datasource;
  final LevelCache cache;

  Future<LevelResult?> readCached() async {
    try {
      final data = await cache.read();
      if (data == null || data.isEmpty) return null;
      return LevelResult(data: data, fromCache: true);
    } catch (_) {
      return null;
    }
  }

  Future<LevelResult> load() async {
    try {
      final history = await datasource.fetchHistory(
        window: AppConfig.historyWindow,
      );
      if (history.isEmpty) {
        throw const LevelDatasourceException('Nessuna misura disponibile');
      }
      final data = LevelData(
        history: history,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      // Un errore del disco non deve scartare misure appena ricevute.
      try {
        await cache.save(data);
      } catch (_) {
        // Il risultato di rete rimane disponibile per questa sessione.
      }
      return LevelResult(data: data, fromCache: false);
    } catch (_) {
      final cached = await readCached();
      if (cached != null) return cached;
      rethrow;
    }
  }
}
