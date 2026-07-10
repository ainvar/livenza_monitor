import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/cache/basin_cache.dart';
import '../../data/datasources/basin_datasource.dart';
import '../../data/repositories/basin_repository.dart';
import 'level_providers.dart';

final basinDatasourceProvider = Provider<BasinDatasource>((ref) {
  return MonitorBasinDatasource(ref.watch(httpClientProvider));
});

/// Factory dei TileProvider della mappa, iniettabile nei test
/// (dove la rete non è disponibile).
///
/// È una factory e non un'istanza condivisa: TileLayer si appropria
/// del TileProvider e lo dispone (chiudendo il suo client HTTP),
/// quindi ogni TileLayer deve averne uno proprio.
final mapTileProviderFactoryProvider = Provider<TileProvider Function()>((
  ref,
) {
  return NetworkTileProvider.new;
});

final basinCacheProvider = Provider<BasinCache>((ref) => BasinCache());

final basinRepositoryProvider = Provider<BasinRepository>((ref) {
  return BasinRepository(
    datasource: ref.watch(basinDatasourceProvider),
    cache: ref.watch(basinCacheProvider),
  );
});

/// Letture del bacino con auto-refresh periodico.
class BasinNotifier extends AsyncNotifier<BasinResult> {
  @override
  Future<BasinResult> build() {
    final timer = Timer.periodic(
      AppConfig.refreshInterval,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(basinRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(basinRepositoryProvider).load(),
    );
  }
}

final basinProvider = AsyncNotifierProvider<BasinNotifier, BasinResult>(
  BasinNotifier.new,
);
