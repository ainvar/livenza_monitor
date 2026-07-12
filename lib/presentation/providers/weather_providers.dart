import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/cache/osmer_cache.dart';
import '../../data/cache/weather_cache.dart';
import '../../data/datasources/ensemble_datasource.dart';
import '../../data/datasources/osmer_datasource.dart';
import '../../data/datasources/weather_datasource.dart';
import '../../data/repositories/osmer_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../../domain/services/forecast_reliability.dart';
import '../../domain/services/scenario_analysis.dart';
import 'level_providers.dart';

final weatherDatasourceProvider = Provider<WeatherDatasource>((ref) {
  return OpenMeteoWeatherDatasource(ref.watch(httpClientProvider));
});

final ensembleDatasourceProvider = Provider<EnsembleDatasource>((ref) {
  return OpenMeteoEnsembleDatasource(ref.watch(httpClientProvider));
});

final weatherCacheProvider = Provider<WeatherCache>((ref) => WeatherCache());

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(
    datasource: ref.watch(weatherDatasourceProvider),
    ensembleDatasource: ref.watch(ensembleDatasourceProvider),
    reliability: const ForecastReliability(),
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

final osmerDatasourceProvider = Provider<OsmerDatasource>((ref) {
  return XmlOsmerDatasource(ref.watch(httpClientProvider));
});

final osmerRepositoryProvider = Provider<OsmerRepository>((ref) {
  return OsmerRepository(
    datasource: ref.watch(osmerDatasourceProvider),
    cache: OsmerCache(),
  );
});

/// Bollettino OSMER: si aggiorna ogni ora (viene emesso circa
/// due volte al giorno).
class OsmerNotifier extends AsyncNotifier<OsmerResult> {
  @override
  Future<OsmerResult> build() {
    final timer = Timer.periodic(
      const Duration(hours: 1),
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(osmerRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(osmerRepositoryProvider).load(),
    );
  }
}

final osmerProvider = AsyncNotifierProvider<OsmerNotifier, OsmerResult>(
  OsmerNotifier.new,
);

/// Analisi degli scenari ensemble, caricata quando si apre la pagina
/// dedicata (autoDispose: si libera e si riscarica alla riapertura).
final scenarioProvider =
    FutureProvider.autoDispose<ScenarioResult?>((ref) async {
  final ensemble =
      await ref.watch(ensembleDatasourceProvider).fetchHourlyPrecipitation();
  return const ScenarioAnalysis().compute(ensemble, now: DateTime.now());
});
