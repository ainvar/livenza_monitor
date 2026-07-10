/// Aggregati dello storico meteo (1940→oggi) per Sacile.
///
/// La serie giornaliera grezza (~31.000 giorni) viene aggregata subito
/// dopo il download: in cache e in memoria restano solo questi riassunti.
library;

/// Valore annuo generico (temperatura media, giorni caldi, ...).
class YearValue {
  const YearValue({required this.year, required this.value});

  final int year;
  final double value;

  Map<String, dynamic> toJson() => {'y': year, 'v': value};

  static YearValue? fromJson(Map<String, dynamic> json) {
    final y = json['y'];
    final v = json['v'];
    if (y is! int || v is! num) return null;
    return YearValue(year: y, value: v.toDouble());
  }
}

/// Pioggia totale di un anno completo.
class YearPrecipitation {
  const YearPrecipitation({required this.year, required this.millimeters});

  final int year;
  final double millimeters;

  Map<String, dynamic> toJson() => {'y': year, 'mm': millimeters};

  static YearPrecipitation? fromJson(Map<String, dynamic> json) {
    final y = json['y'];
    final mm = json['mm'];
    if (y is! int || mm is! num) return null;
    return YearPrecipitation(year: y, millimeters: mm.toDouble());
  }
}

/// Pioggia di un singolo giorno (per i record).
class DayPrecipitation {
  const DayPrecipitation({required this.date, required this.millimeters});

  final DateTime date;
  final double millimeters;

  Map<String, dynamic> toJson() =>
      {'d': date.toIso8601String(), 'mm': millimeters};

  static DayPrecipitation? fromJson(Map<String, dynamic> json) {
    final d = json['d'];
    final mm = json['mm'];
    if (d is! String || mm is! num) return null;
    final parsed = DateTime.tryParse(d);
    if (parsed == null) return null;
    return DayPrecipitation(date: parsed, millimeters: mm.toDouble());
  }
}

/// Punto della cumulata: pioggia totale dall'inizio dell'anno.
class CumulativePoint {
  const CumulativePoint({required this.dayOfYear, required this.millimeters});

  final int dayOfYear;
  final double millimeters;

  Map<String, dynamic> toJson() => {'d': dayOfYear, 'mm': millimeters};

  static CumulativePoint? fromJson(Map<String, dynamic> json) {
    final d = json['d'];
    final mm = json['mm'];
    if (d is! int || mm is! num) return null;
    return CumulativePoint(dayOfYear: d, millimeters: mm.toDouble());
  }
}

/// Tutti gli aggregati dello storico.
class WeatherHistory {
  const WeatherHistory({
    required this.yearTotals,
    required this.climatologyCumulative,
    required this.currentYear,
    required this.currentYearCumulative,
    required this.topDays,
    required this.annualMeanTemp,
    required this.baselineTemp,
    required this.hotDays,
    required this.lastDataDate,
    required this.fetchedAtUtc,
  });

  /// Pioggia annua degli anni completi (dal 1940).
  final List<YearPrecipitation> yearTotals;

  /// Cumulata media a fine di ciascun mese nel periodo climatico
  /// di riferimento (12 valori, gen→dic).
  final List<double> climatologyCumulative;

  /// Anno della cumulata corrente.
  final int currentYear;

  /// Cumulata giornaliera dell'anno corrente.
  final List<CumulativePoint> currentYearCumulative;

  /// Giorni più piovosi di sempre, in ordine decrescente.
  final List<DayPrecipitation> topDays;

  /// Temperatura media annua degli anni completi (°C).
  final List<YearValue> annualMeanTemp;

  /// Media delle temperature annue nel periodo baseline
  /// (riferimento per le anomalie).
  final double baselineTemp;

  /// Giorni con massima sopra soglia, per anno.
  final List<YearValue> hotDays;

  /// Ultimo giorno con dato disponibile.
  final DateTime lastDataDate;

  final DateTime fetchedAtUtc;

  Map<String, dynamic> toCacheJson() => {
        'years': [for (final y in yearTotals) y.toJson()],
        'climatology': climatologyCumulative,
        'currentYear': currentYear,
        'cumulative': [for (final c in currentYearCumulative) c.toJson()],
        'topDays': [for (final d in topDays) d.toJson()],
        'temps': [for (final t in annualMeanTemp) t.toJson()],
        'baselineTemp': baselineTemp,
        'hotDays': [for (final h in hotDays) h.toJson()],
        'lastDataDate': lastDataDate.toIso8601String(),
        'fetchedAt': fetchedAtUtc.toIso8601String(),
      };

  static WeatherHistory? fromCacheJson(Map<String, dynamic> json) {
    final years = json['years'];
    final climatology = json['climatology'];
    final currentYear = json['currentYear'];
    final cumulative = json['cumulative'];
    final topDays = json['topDays'];
    final temps = json['temps'];
    final baselineTemp = json['baselineTemp'];
    final hotDays = json['hotDays'];
    final lastDataDate = json['lastDataDate'];
    final fetchedAt = json['fetchedAt'];
    if (years is! List ||
        climatology is! List ||
        currentYear is! int ||
        cumulative is! List ||
        topDays is! List ||
        temps is! List ||
        baselineTemp is! num ||
        hotDays is! List ||
        lastDataDate is! String ||
        fetchedAt is! String) {
      return null;
    }
    final parsedLast = DateTime.tryParse(lastDataDate);
    final parsedFetched = DateTime.tryParse(fetchedAt);
    if (parsedLast == null || parsedFetched == null) return null;
    return WeatherHistory(
      yearTotals: [
        for (final y in years)
          if (y is Map<String, dynamic>) ?YearPrecipitation.fromJson(y),
      ],
      climatologyCumulative: [
        for (final v in climatology)
          if (v is num) v.toDouble(),
      ],
      currentYear: currentYear,
      currentYearCumulative: [
        for (final c in cumulative)
          if (c is Map<String, dynamic>) ?CumulativePoint.fromJson(c),
      ],
      topDays: [
        for (final d in topDays)
          if (d is Map<String, dynamic>) ?DayPrecipitation.fromJson(d),
      ],
      annualMeanTemp: [
        for (final t in temps)
          if (t is Map<String, dynamic>) ?YearValue.fromJson(t),
      ],
      baselineTemp: baselineTemp.toDouble(),
      hotDays: [
        for (final h in hotDays)
          if (h is Map<String, dynamic>) ?YearValue.fromJson(h),
      ],
      lastDataDate: parsedLast,
      fetchedAtUtc: parsedFetched.toUtc(),
    );
  }
}
