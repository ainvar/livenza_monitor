import '../../data/datasources/ensemble_datasource.dart';

/// Analisi degli scenari ensemble: percentili della pioggia cumulata
/// sui prossimi giorni.
class ScenarioResult {
  const ScenarioResult({
    required this.times,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.memberCount,
    required this.exceedanceProbability,
  });

  /// Orari dei passi della cumulata (futuri, ordinati).
  final List<DateTime> times;

  /// Percentili della pioggia cumulata (mm), uno per passo.
  final List<double> p10;
  final List<double> p25;
  final List<double> p50;
  final List<double> p75;
  final List<double> p90;

  final int memberCount;

  /// Probabilità (%) che la cumulata totale superi la soglia (mm).
  final Map<int, int> exceedanceProbability;

  /// Cumulata totale nei tre scenari di sintesi.
  double get dryTotal => p10.last;
  double get medianTotal => p50.last;
  double get wetTotal => p90.last;
}

/// Calcola gli scenari dalla nuvola di membri. Logica pura.
class ScenarioAnalysis {
  const ScenarioAnalysis();

  /// Soglie di cumulata (mm) per le probabilità di superamento.
  static const thresholds = [20, 50, 100];

  /// Restituisce null se i dati futuri sono insufficienti.
  ScenarioResult? compute(EnsembleHourly data, {required DateTime now}) {
    final indices = <int>[
      for (var i = 0; i < data.times.length; i++)
        if (data.times[i].isAfter(now)) i,
    ];
    if (indices.length < 24 || data.members.isEmpty) return null;

    // Cumulate per membro a ogni passo.
    final steps = indices.length;
    final cumulative = <List<double>>[
      for (final member in data.members)
        _runningSum([for (final i in indices) member[i]]),
    ];

    // Percentili passo per passo.
    final p10 = <double>[];
    final p25 = <double>[];
    final p50 = <double>[];
    final p75 = <double>[];
    final p90 = <double>[];
    for (var s = 0; s < steps; s++) {
      final values = [for (final c in cumulative) c[s]]..sort();
      p10.add(_percentile(values, 10));
      p25.add(_percentile(values, 25));
      p50.add(_percentile(values, 50));
      p75.add(_percentile(values, 75));
      p90.add(_percentile(values, 90));
    }

    // Probabilità di superamento delle soglie sulla cumulata totale.
    final totals = [for (final c in cumulative) c.last];
    final exceedance = <int, int>{
      for (final t in thresholds)
        t: ([for (final v in totals) if (v >= t) v].length *
                100 /
                totals.length)
            .round(),
    };

    return ScenarioResult(
      times: [for (final i in indices) data.times[i]],
      p10: p10,
      p25: p25,
      p50: p50,
      p75: p75,
      p90: p90,
      memberCount: data.members.length,
      exceedanceProbability: exceedance,
    );
  }

  List<double> _runningSum(List<double> values) {
    final result = <double>[];
    var sum = 0.0;
    for (final v in values) {
      sum += v;
      result.add(sum);
    }
    return result;
  }

  /// Percentile con interpolazione lineare su valori già ordinati.
  double _percentile(List<double> sorted, int percent) {
    if (sorted.length == 1) return sorted.first;
    final position = (sorted.length - 1) * percent / 100;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }
}
