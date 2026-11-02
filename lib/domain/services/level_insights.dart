import 'dart:math' as math;

import '../../core/config/app_config.dart';
import '../../data/models/hydro_measure.dart';

/// Sintesi delle misure disponibili, senza estrapolazioni del livello futuro.
class LevelInsights {
  const LevelInsights();

  /// Differenza rispetto alla misura vicina all'inizio della finestra.
  /// Una serie troppo corta o con un buco non diventa una falsa variazione.
  double? change(List<HydroMeasure> history, Duration window) {
    if (history.length < 2) return null;
    final latest = history.last;
    final target = latest.timestampUtc.subtract(window);
    HydroMeasure? reference;
    var distance = const Duration(days: 36500);
    for (final measure in history) {
      if (!measure.timestampUtc.isBefore(latest.timestampUtc)) continue;
      final candidate = measure.timestampUtc.difference(target).abs();
      if (candidate < distance) {
        distance = candidate;
        reference = measure;
      }
    }
    if (reference == null || distance > const Duration(minutes: 20)) {
      return null;
    }
    return latest.value - reference.value;
  }

  HydroMeasure? peak(List<HydroMeasure> history) {
    if (history.isEmpty) return null;
    return history.reduce((a, b) => b.value >= a.value ? b : a);
  }

  /// Scala che include sempre i valori, anche oltre le soglie indicative.
  ({double min, double max}) chartRange(List<HydroMeasure> history) {
    if (history.isEmpty) return (min: 0, max: 1);
    final low = history.map((m) => m.value).reduce(math.min);
    final high = history.map((m) => m.value).reduce(math.max);
    final min = low < 0.3 ? low - 0.3 : math.max(0.0, low - 0.3);
    final max = high >= AppConfig.sogliaGialla - 1
        ? math.max(high + 0.3, AppConfig.sogliaRossa + 0.4)
        : high + 0.3;
    return (min: min, max: max);
  }
}
