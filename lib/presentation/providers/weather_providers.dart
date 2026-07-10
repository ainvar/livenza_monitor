import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/cache/weather_cache.dart';
import '../../data/datasources/weather_datasource.dart';
import '../../data/repositories/weather_repository.dart';
import 'level_providers.dart';

final weatherDatasourceProvider = Provider<WeatherDatasource>((ref) {
  return OpenMeteoWeatherDatasource(ref.watch(httpClientProvider));
});

final weatherCacheProvider = Provider<WeatherCache>((ref) => WeatherCache());

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(
    datasource: ref.watch(weatherDatasourceProvider),
    cache: ref.watch(weatherCacheProvider),
  );
});

/// Meteo con auto-refresh periodico (le previsioni cambiano lentamente:
/// si aggiorna a ogni intervallo doppio rispetto ai livelli).
class WeatherNotifier extends AsyncNotifier<WeatherResult> {
  @override
  Future<WeatherResult> build() {
    final timer = Timer.periodic(
      AppConfig.refreshInterval * 2,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(weatherRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(weatherRepositoryProvider).load(),
    );
  }
}

final weatherProvider = AsyncNotifierProvider<WeatherNotifier, WeatherResult>(
  WeatherNotifier.new,
);
