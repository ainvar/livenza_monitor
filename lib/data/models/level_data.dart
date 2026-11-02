import 'hydro_measure.dart';

/// Serie storica dei livelli con il momento in cui è stata scaricata.
class LevelData {
  const LevelData({required this.history, required this.fetchedAtUtc});

  /// Misure ordinate per tempo crescente.
  final List<HydroMeasure> history;

  /// Quando i dati sono stati scaricati dalla rete (UTC).
  final DateTime fetchedAtUtc;

  /// Misura più recente disponibile.
  HydroMeasure? get latest => history.isEmpty ? null : history.last;

  bool get isEmpty => history.isEmpty;

  Map<String, dynamic> toCacheJson() => {
    'fetchedAt': fetchedAtUtc.toIso8601String(),
    'measures': [for (final m in history) m.toCacheJson()],
  };

  static LevelData? fromCacheJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'];
    final measures = json['measures'];
    if (fetchedAt is! String || measures is! List) return null;
    final parsed = DateTime.tryParse(fetchedAt);
    if (parsed == null) return null;
    final history = <HydroMeasure>[
      for (final m in measures)
        if (m is Map<String, dynamic>) ?HydroMeasure.fromCacheJson(m),
    ];
    return LevelData(history: history, fetchedAtUtc: parsed.toUtc());
  }
}
