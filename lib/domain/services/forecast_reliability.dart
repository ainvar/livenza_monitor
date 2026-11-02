import '../../data/datasources/ensemble_datasource.dart';

/// Affidabilità calcolata: percentuali di concordanza tra i membri
/// dell'ensemble sull'esito "pioggia / non pioggia".
class ReliabilityResult {
  const ReliabilityResult({required this.daily, required this.next48h});

  /// Percentuale (50–100) per giorno di calendario.
  final Map<DateTime, int> daily;

  /// Percentuale sulla finestra delle prossime 48 ore.
  final int? next48h;
}

/// Calcola l'affidabilità della previsione come concordanza tra gli
/// scenari dell'ensemble. Logica pura, testabile.
///
/// Con N membri, l'accordo va dal 50% (metà prevede pioggia, metà no:
/// massima incertezza) al 100% (tutti concordi).
class ForecastReliability {
  const ForecastReliability();

  /// Sopra questa soglia il giorno/finestra conta come "piovoso".
  static const double rainThresholdMm = 1.0;

  ReliabilityResult compute(EnsembleHourly data, {required DateTime now}) {
    // Indici delle ore raggruppati per giorno di calendario.
    final dayIndices = <DateTime, List<int>>{};
    for (var i = 0; i < data.times.length; i++) {
      final t = data.times[i];
      final day = DateTime(t.year, t.month, t.day);
      dayIndices.putIfAbsent(day, () => []).add(i);
    }

    final daily = <DateTime, int>{};
    for (final entry in dayIndices.entries) {
      // Giorni troncati (a fine orizzonte) sarebbero fuorvianti.
      if (entry.value.length != 24 ||
          data.times[entry.value.first].hour != 0 ||
          data.times[entry.value.last].hour != 23 ||
          !_continuous(data, entry.value)) {
        continue;
      }
      final members = data.completeMembers(entry.value);
      if (members.isNotEmpty) daily[entry.key] = _agreement(members);
    }

    // Finestra delle prossime 48 ore.
    final window = <int>[
      for (var i = 0; i < data.times.length; i++)
        if (data.times[i].isAfter(now) &&
            !data.times[i].isAfter(now.add(const Duration(hours: 48))))
          i,
    ];
    final members = data.completeMembers(window);
    final next48h =
        window.length < 48 ||
            data.times[window.first].difference(now) >
                const Duration(hours: 1) ||
            !_continuous(data, window) ||
            members.isEmpty
        ? null
        : _agreement(members);

    return ReliabilityResult(daily: daily, next48h: next48h);
  }

  /// Percentuale di membri d'accordo con l'esito di maggioranza.
  bool _continuous(EnsembleHourly data, List<int> indices) {
    for (var i = 1; i < indices.length; i++) {
      if (data.times[indices[i]].difference(data.times[indices[i - 1]]) !=
          const Duration(hours: 1)) {
        return false;
      }
    }
    return true;
  }

  int _agreement(List<List<double>> members) {
    var rainy = 0;
    for (final member in members) {
      var sum = 0.0;
      for (final value in member) {
        sum += value;
      }
      if (sum >= rainThresholdMm) rainy++;
    }
    final majority = rainy >= members.length - rainy
        ? rainy
        : members.length - rainy;
    return (majority * 100 / members.length).round();
  }
}
