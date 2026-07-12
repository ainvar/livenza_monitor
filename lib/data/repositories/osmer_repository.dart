import '../cache/osmer_cache.dart';
import '../datasources/osmer_datasource.dart';
import '../models/osmer_bulletin.dart';

/// Esito del caricamento bollettino.
class OsmerResult {
  const OsmerResult({required this.bulletin, required this.fromCache});

  final OsmerBulletin bulletin;
  final bool fromCache;
}

/// Rete prima, cache come ripiego.
class OsmerRepository {
  OsmerRepository({required this.datasource, required this.cache});

  final OsmerDatasource datasource;
  final OsmerCache cache;

  Future<OsmerResult> load() async {
    try {
      final bulletin = await datasource.fetchBulletin();
      await cache.save(bulletin);
      return OsmerResult(bulletin: bulletin, fromCache: false);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) {
        return OsmerResult(bulletin: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
