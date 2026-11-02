import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/threshold_colors.dart';
import '../../data/models/hydro_measure.dart';
import 'level_insights.dart';

/// Stato di allerta derivato dal livello idrometrico a Sacile.
enum AlertLevel { unknown, normal, yellow, red }

/// Tendenza del livello nell'ultima ora.
enum LevelTrend { unknown, falling, steady, rising }

/// Regole di dominio: classificazione del livello e calcolo del trend.
class AlertService {
  const AlertService();

  /// Variazione minima (m) sull'ultima ora per considerare il livello
  /// in salita o in discesa anziché stabile.
  static const double _trendEpsilon = 0.03;

  /// Classifica un livello rispetto alle soglie di Sacile:
  /// gialla >= 5,5 m, rossa >= 6,0 m.
  AlertLevel classify(double? level) {
    if (level == null) return AlertLevel.unknown;
    if (level >= AppConfig.sogliaRossa) return AlertLevel.red;
    if (level >= AppConfig.sogliaGialla) return AlertLevel.yellow;
    return AlertLevel.normal;
  }

  /// Calcola la tendenza confrontando l'ultima misura con quella
  /// più vicina a un'ora prima.
  LevelTrend trend(List<HydroMeasure> history) {
    final delta = const LevelInsights().change(
      history,
      const Duration(hours: 1),
    );
    if (delta == null) return LevelTrend.unknown;
    if (delta >= _trendEpsilon) return LevelTrend.rising;
    if (delta <= -_trendEpsilon) return LevelTrend.falling;
    return LevelTrend.steady;
  }
}

/// Presentazione degli stati di allerta (colore e testo).
extension AlertLevelUi on AlertLevel {
  Color get color => switch (this) {
    AlertLevel.normal => ThresholdColors.normal,
    AlertLevel.yellow => ThresholdColors.soglia1,
    AlertLevel.red => ThresholdColors.soglia3,
    AlertLevel.unknown => ThresholdColors.unknown,
  };

  String get label => switch (this) {
    AlertLevel.normal => 'Sotto le soglie indicative',
    AlertLevel.yellow => 'Soglia indicativa gialla superata',
    AlertLevel.red => 'Soglia indicativa rossa superata',
    AlertLevel.unknown => 'Livello non disponibile',
  };
}

extension LevelTrendUi on LevelTrend {
  IconData get icon => switch (this) {
    LevelTrend.rising => Icons.trending_up,
    LevelTrend.falling => Icons.trending_down,
    LevelTrend.steady => Icons.trending_flat,
    LevelTrend.unknown => Icons.help_outline,
  };

  String get label => switch (this) {
    LevelTrend.rising => 'In salita',
    LevelTrend.falling => 'In discesa',
    LevelTrend.steady => 'Stabile',
    LevelTrend.unknown => 'Trend n/d',
  };
}
