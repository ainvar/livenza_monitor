import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/cache/alert_cache.dart';
import '../../data/datasources/cfd_alert_datasource.dart';
import '../../data/repositories/alert_repository.dart';
import 'level_providers.dart';

final cfdAlertDatasourceProvider = Provider<CfdAlertDatasource>((ref) {
  return HttpCfdAlertDatasource(ref.watch(httpClientProvider));
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(
    datasource: ref.watch(cfdAlertDatasourceProvider),
    cache: AlertCache(),
  );
});

/// Allerte regionali, aggiornate ogni 15 minuti.
class RegionalAlertNotifier extends AsyncNotifier<AlertResult> {
  @override
  Future<AlertResult> build() {
    final timer = Timer.periodic(
      AppConfig.refreshInterval * 3,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(alertRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(alertRepositoryProvider).load(),
    );
  }
}

final regionalAlertProvider =
    AsyncNotifierProvider<RegionalAlertNotifier, AlertResult>(
      RegionalAlertNotifier.new,
    );
