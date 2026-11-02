import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache/osmer_cache.dart';
import '../../data/cache/weather_cache.dart';
import '../../data/datasources/ensemble_datasource.dart';
import '../../data/datasources/osmer_datasource.dart';
import '../../data/datasources/weather_datasource.dart';
import '../../data/repositories/osmer_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../../data/repositories/ensemble_repository.dart';
import '../../data/models/weather_location.dart';
import '../../domain/services/scenario_analysis.dart';
import '../../domain/services/forecast_reliability.dart';
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
    cache: ref.watch(weatherCacheProvider),
  );
});

final selectedWeatherLocationProvider = StateProvider<int>((ref) => 543);

WeatherLocation weatherLocationById(int id) =>
    weatherLocations.firstWhere((point) => point.id == id);

final weatherRepositoryForLocationProvider =
    Provider.family<WeatherRepository, int>((ref, id) {
      if (id == 543) return ref.watch(weatherRepositoryProvider);
      return WeatherRepository(
        datasource: OpenMeteoWeatherDatasource(
          ref.watch(httpClientProvider),
          location: weatherLocationById(id),
        ),
        cache: WeatherCache(locationId: id),
      );
    });

/// I timer esistono solo per i punti effettivamente osservati dalla UI.
class WeatherLocationNotifier
    extends AutoDisposeFamilyAsyncNotifier<WeatherResult, int> {
  late int _locationId;

  @override
  Future<WeatherResult> build(int locationId) {
    _locationId = locationId;
    final timer = Timer.periodic(
      WeatherRepository.maxAge,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(weatherRepositoryForLocationProvider(locationId)).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref
          .read(weatherRepositoryForLocationProvider(_locationId))
          .load(force: true),
    );
  }
}

final weatherForLocationProvider = AsyncNotifierProvider.autoDispose
    .family<WeatherLocationNotifier, WeatherResult, int>(
      WeatherLocationNotifier.new,
    );

/// La Home resta sempre su Sacile, anche selezionando altri punti nel Meteo.
final sacileWeatherSummaryProvider = Provider<AsyncValue<WeatherResult>>(
  (ref) => ref.watch(weatherForLocationProvider(543)),
);

class WeatherNotifier extends AsyncNotifier<WeatherResult> {
  @override
  Future<WeatherResult> build() {
    final id = ref.watch(selectedWeatherLocationProvider);
    return ref.watch(weatherForLocationProvider(id).future);
  }

  Future<void> refresh() async {
    final id = ref.read(selectedWeatherLocationProvider);
    await ref.read(weatherForLocationProvider(id).notifier).refresh();
    try {
      await ref.read(ensembleRepositoryProvider(id)).load(force: true);
    } catch (_) {
      // Il forecast base resta visibile anche senza l'ensemble.
    }
    ref.invalidate(ensembleForLocationProvider(id));
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

final ensembleRepositoryProvider = Provider.family<EnsembleRepository, int>((
  ref,
  id,
) {
  return EnsembleRepository(
    datasource: id == 543
        ? ref.watch(ensembleDatasourceProvider)
        : OpenMeteoEnsembleDatasource(
            ref.watch(httpClientProvider),
            location: weatherLocationById(id),
          ),
    locationId: id,
  );
});

final ensembleForLocationProvider = FutureProvider.autoDispose
    .family<EnsembleResult, int>((ref, id) {
      return ref.watch(ensembleRepositoryProvider(id)).load();
    });

/// Il forecast base compare subito; la concordanza si aggiunge quando pronta.
final forecastAgreementProvider = Provider.autoDispose<ReliabilityResult?>((
  ref,
) {
  final id = ref.watch(selectedWeatherLocationProvider);
  final ensemble = ref.watch(ensembleForLocationProvider(id)).valueOrNull;
  if (ensemble == null) return null;
  return const ForecastReliability().compute(
    ensemble.data,
    now: DateTime.now(),
  );
});

Future<void> refreshEnsemble(WidgetRef ref) async {
  final id = ref.read(selectedWeatherLocationProvider);
  await ref.read(ensembleRepositoryProvider(id)).load(force: true);
  ref.invalidate(ensembleForLocationProvider(id));
}

/// Condivide la stessa richiesta/cache usata dalle percentuali nella UI.
final scenarioProvider = FutureProvider.autoDispose<ScenarioResult?>((
  ref,
) async {
  final id = ref.watch(selectedWeatherLocationProvider);
  final ensemble = await ref.watch(ensembleForLocationProvider(id).future);
  return const ScenarioAnalysis().compute(ensemble.data, now: DateTime.now());
});
