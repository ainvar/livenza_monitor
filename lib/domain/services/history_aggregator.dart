import '../../core/config/app_config.dart';
import '../../data/datasources/history_datasource.dart';
import '../../data/models/weather_history.dart';

/// Trasforma la serie giornaliera grezza (1940→oggi) negli aggregati
/// mostrati dalle sezioni Storico e Temperature. Logica pura, senza I/O.
class HistoryAggregator {
  const HistoryAggregator();

  /// Numero di giorni record da conservare.
  static const int topDaysCount = 10;

  /// Giorni minimi con dato perché la media annua sia significativa.
  static const int _minDaysPerYear = 300;

  WeatherHistory aggregate(
    List<RawDailyWeather> raw, {
    required DateTime fetchedAtUtc,
  }) {
    // Ultimo giorno con almeno un dato (la coda recente può essere null).
    DateTime? lastDataDate;
    for (final day in raw) {
      if (day.precipitation != null || day.tMean != null) {
        lastDataDate = day.date;
      }
    }
    if (lastDataDate == null) {
      throw StateError('Serie storica vuota');
    }
    final currentYear = lastDataDate.year;

    // --- Pioggia ---------------------------------------------------------
    final rainDays = <(DateTime, double)>[
      for (final day in raw)
        if (day.precipitation case final mm?) (day.date, mm),
    ];

    final yearSums = <int, double>{};
    final monthSums = <(int, int), double>{};
    for (final (date, mm) in rainDays) {
      yearSums.update(date.year, (v) => v + mm, ifAbsent: () => mm);
      monthSums.update(
        (date.year, date.month),
        (v) => v + mm,
        ifAbsent: () => mm,
      );
    }

    final yearTotals = [
      for (final year in yearSums.keys.toList()..sort())
        if (year < currentYear)
          YearPrecipitation(year: year, millimeters: yearSums[year]!),
    ];

    // Climatologia: media dei totali mensili nel periodo di riferimento,
    // poi cumulata gen→dic.
    final climatologyCumulative = <double>[];
    var running = 0.0;
    for (var month = 1; month <= 12; month++) {
      var sum = 0.0;
      var count = 0;
      for (
        var year = AppConfig.climatologyStartYear;
        year <= AppConfig.climatologyEndYear;
        year++
      ) {
        final total = monthSums[(year, month)];
        if (total != null) {
          sum += total;
          count++;
        }
      }
      running += count == 0 ? 0 : sum / count;
      climatologyCumulative.add(running);
    }

    // Cumulata giornaliera dell'anno corrente. Il giorno dell'anno è
    // calcolato in UTC su sole date, per non sbagliare di uno al
    // cambio dell'ora legale.
    final currentYearCumulative = <CumulativePoint>[];
    var cumulative = 0.0;
    final startOfYear = DateTime.utc(currentYear);
    for (final (date, mm) in rainDays) {
      if (date.year != currentYear) continue;
      cumulative += mm;
      currentYearCumulative.add(
        CumulativePoint(
          dayOfYear:
              DateTime.utc(
                date.year,
                date.month,
                date.day,
              ).difference(startOfYear).inDays +
              1,
          millimeters: cumulative,
        ),
      );
    }

    // Giorni più piovosi di sempre.
    final sortedRain = [...rainDays]..sort((a, b) => b.$2.compareTo(a.$2));
    final topDays = [
      for (final (date, mm) in sortedRain.take(topDaysCount))
        DayPrecipitation(date: date, millimeters: mm),
    ];

    // --- Temperature ------------------------------------------------------
    final tempSum = <int, double>{};
    final tempCount = <int, int>{};
    final hotCount = <int, int>{};
    final tMaxCount = <int, int>{};
    for (final day in raw) {
      final year = day.date.year;
      if (day.tMean case final t?) {
        tempSum.update(year, (v) => v + t, ifAbsent: () => t);
        tempCount.update(year, (v) => v + 1, ifAbsent: () => 1);
      }
      if (day.tMax case final t?) {
        tMaxCount.update(year, (v) => v + 1, ifAbsent: () => 1);
        if (t >= AppConfig.hotDayThreshold) {
          hotCount.update(year, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    // Media annua: solo anni completi e con copertura sufficiente.
    final annualMeanTemp = [
      for (final year in tempSum.keys.toList()..sort())
        if (year < currentYear && tempCount[year]! >= _minDaysPerYear)
          YearValue(year: year, value: tempSum[year]! / tempCount[year]!),
    ];

    // Baseline pre-riscaldamento per le anomalie; se il periodo non è
    // coperto si ripiega sulla media dell'intera serie.
    var baselineSum = 0.0;
    var baselineCount = 0;
    for (final t in annualMeanTemp) {
      if (t.year >= AppConfig.baselineStartYear &&
          t.year <= AppConfig.baselineEndYear) {
        baselineSum += t.value;
        baselineCount++;
      }
    }
    if (baselineCount == 0) {
      for (final t in annualMeanTemp) {
        baselineSum += t.value;
        baselineCount++;
      }
    }
    final baselineTemp = baselineCount == 0 ? 0.0 : baselineSum / baselineCount;

    // Giorni molto caldi per anno (conteggio 0 incluso).
    final hotDays = [
      for (final year in tMaxCount.keys.toList()..sort())
        if (year < currentYear && tMaxCount[year]! >= _minDaysPerYear)
          YearValue(year: year, value: (hotCount[year] ?? 0).toDouble()),
    ];

    return WeatherHistory(
      yearTotals: yearTotals,
      climatologyCumulative: climatologyCumulative,
      currentYear: currentYear,
      currentYearCumulative: currentYearCumulative,
      topDays: topDays,
      annualMeanTemp: annualMeanTemp,
      baselineTemp: baselineTemp,
      hotDays: hotDays,
      lastDataDate: lastDataDate,
      fetchedAtUtc: fetchedAtUtc,
    );
  }
}
