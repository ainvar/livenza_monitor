import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import 'status_banner.dart';

final _timeFormat = DateFormat('HH:mm');
final _dayTimeFormat = DateFormat('dd/MM HH:mm');

/// Età oltre la quale una misura è considerata "vecchia"
/// (stazione che non trasmette): ~90 minuti.
final _staleMeasureAge = AppConfig.cacheMaxAge * 9;

/// Costruisce lo [StatusBanner] per uno stato dati asincrono.
///
/// [fetchedAtUtc] è quando i dati sono stati scaricati, [newestMeasureUtc]
/// la misura più recente contenuta, [fromCache] se provengono dalla cache.
StatusBanner dataStatusBanner<T>({
  required AsyncValue<T> state,
  required DateTime? Function(T value) fetchedAtUtc,
  required DateTime? Function(T value) newestMeasureUtc,
  required bool Function(T value) fromCache,
}) {
  final value = state.valueOrNull;
  if (value != null) {
    final fetched = fetchedAtUtc(value);
    final fetchedLabel = fetched == null
        ? ''
        : _timeFormat.format(fetched.toLocal());
    if (fromCache(value)) {
      return StatusBanner(
        status: BannerStatus.stale,
        message: fetched == null
            ? 'Ultimi dati salvati sul dispositivo'
            : 'Dati salvati · ${_dayTimeFormat.format(fetched.toLocal())}',
      );
    }
    final newest = newestMeasureUtc(value);
    final measureAge = newest == null
        ? null
        : DateTime.now().toUtc().difference(newest);
    if (measureAge == null || measureAge > _staleMeasureAge) {
      return StatusBanner(
        status: BannerStatus.stale,
        message: newest == null
            ? 'Nessuna misura recente dalla stazione'
            : 'Ultima misura: ${_dayTimeFormat.format(newest.toLocal())}',
      );
    }
    return StatusBanner(
      status: BannerStatus.fresh,
      message: 'Aggiornato alle $fetchedLabel',
    );
  }
  if (state.hasError) {
    return const StatusBanner(
      status: BannerStatus.offline,
      message: 'Dati non disponibili: controlla la connessione',
    );
  }
  return const StatusBanner(
    status: BannerStatus.loading,
    message: 'Caricamento dati…',
  );
}
