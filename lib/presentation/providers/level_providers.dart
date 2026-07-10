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
  @override
  Future<LevelResult> build() {
    final timer = Timer.periodic(
      AppConfig.refreshInterval,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(levelRepositoryProvider).load();
  }

  /// Refresh manuale (pull-to-refresh o pulsante) che mantiene
  /// visibili i dati correnti durante il caricamento.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(levelRepositoryProvider).load(),
    );
  }
}

final levelProvider = AsyncNotifierProvider<LevelNotifier, LevelResult>(
  LevelNotifier.new,
);
