import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache/station_history_cache.dart';
import '../../data/datasources/station_history_datasource.dart';
import '../../data/repositories/station_history_repository.dart';
import 'level_providers.dart';

final stationHistoryDatasourceProvider = Provider<StationHistoryDatasource>(
  (ref) => MonitorStationHistoryDatasource(ref.watch(httpClientProvider)),
);

final stationHistoryCacheProvider = Provider((ref) => StationHistoryCache());

final stationHistoryRepositoryProvider = Provider((ref) {
  return StationHistoryRepository(
    datasource: ref.watch(stationHistoryDatasourceProvider),
    cache: ref.watch(stationHistoryCacheProvider),
  );
});

/// Nessun download dello storico fino all'apertura del dettaglio stazione.
final stationHistoryProvider = FutureProvider.autoDispose
    .family<StationHistoryResult, int>(
      (ref, stationId) =>
          ref.watch(stationHistoryRepositoryProvider).load(stationId),
    );
