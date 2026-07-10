import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache/history_cache.dart';
import '../../data/datasources/history_datasource.dart';
import '../../data/repositories/history_repository.dart';
import '../../domain/services/history_aggregator.dart';
import 'level_providers.dart';

final historyDatasourceProvider = Provider<HistoryDatasource>((ref) {
  return OpenMeteoHistoryDatasource(ref.watch(httpClientProvider));
});

final historyCacheProvider = Provider<HistoryCache>((ref) => HistoryCache());

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(
    datasource: ref.watch(historyDatasourceProvider),
    cache: ref.watch(historyCacheProvider),
    aggregator: const HistoryAggregator(),
  );
});

/// Storico meteo: si carica alla prima apertura della sezione,
/// nessun refresh periodico (cambia una volta al giorno al più).
class HistoryNotifier extends AsyncNotifier<HistoryResult> {
  @override
  Future<HistoryResult> build() {
    return ref.watch(historyRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(historyRepositoryProvider).load(force: true),
    );
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, HistoryResult>(
  HistoryNotifier.new,
);
