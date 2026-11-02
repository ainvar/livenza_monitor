import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../data/cache/level_cache.dart';
import '../../data/datasources/level_datasource.dart';
import '../../data/repositories/level_repository.dart';
import '../../domain/services/alert_service.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final levelDatasourceProvider = Provider<LevelDatasource>((ref) {
  // Quando esisterà il backend Cloudflare, qui si sceglierà
  // l'implementazione in base ad AppConfig.useBackend.
  return MonitorLevelDatasource(ref.watch(httpClientProvider));
});

final levelCacheProvider = Provider<LevelCache>((ref) => LevelCache());

final levelRepositoryProvider = Provider<LevelRepository>((ref) {
  return LevelRepository(
    datasource: ref.watch(levelDatasourceProvider),
    cache: ref.watch(levelCacheProvider),
  );
});

final alertServiceProvider = Provider<AlertService>(
  (ref) => const AlertService(),
);

/// Stato dei livelli, con refresh automatico ogni [AppConfig.refreshInterval].
class LevelNotifier extends AsyncNotifier<LevelResult> {
  bool _disposed = false;
  Future<void>? _refreshing;

  @override
  Future<LevelResult> build() async {
    _disposed = false;
    final repository = ref.watch(levelRepositoryProvider);
    final timer = Timer.periodic(
      AppConfig.refreshInterval,
      (_) => unawaited(refresh()),
    );
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });
    final cached = await repository.readCached();
    if (cached != null) {
      // Il primo frame mostra subito la cache; la rete la aggiorna dopo.
      Timer.run(() {
        if (!_disposed) unawaited(refresh());
      });
      return cached;
    }
    return repository.load();
  }

  /// Refresh manuale (pull-to-refresh o pulsante) che mantiene
  /// visibili i dati correnti durante il caricamento.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final next = await AsyncValue.guard(
      () => ref.read(levelRepositoryProvider).load(),
    );
    if (_disposed) return;
    final previous = state.valueOrNull;
    state = next.hasError && previous != null
        ? AsyncData(LevelResult(data: previous.data, fromCache: true))
        : next;
  }
}

final levelProvider = AsyncNotifierProvider<LevelNotifier, LevelResult>(
  LevelNotifier.new,
);
