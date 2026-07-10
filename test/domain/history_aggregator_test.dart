import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/datasources/history_datasource.dart';
import 'package:livenza_monitor/data/models/weather_history.dart';
import 'package:livenza_monitor/domain/services/history_aggregator.dart';

void main() {
  const aggregator = HistoryAggregator();
  final fetchedAt = DateTime.utc(2026, 7, 2);

  RawDailyWeather day(
    DateTime date, {
    double? mm,
    double? tMean,
    double? tMax,
  }) =>
      (date: date, precipitation: mm, tMean: tMean, tMax: tMax);

  /// Serie sintetica: tutti i giorni di [year]. Le date sono costruite
  /// per indice (non con add di 24 ore) per evitare slittamenti al
  /// cambio dell'ora legale.
  List<RawDailyWeather> fullYear(
    int year, {
    double mm = 0,
    double tMean = 12,
    double tMax = 18,
  }) {
    final result = <RawDailyWeather>[];
    for (var i = 0;; i++) {
      final d = DateTime(year, 1, 1 + i);
      if (d.year != year) break;
      result.add(day(d, mm: mm, tMean: tMean, tMax: tMax));
    }
    return result;
  }

  group('pioggia', () {
    test('esclude l\'anno in corso dai totali annui', () {
      final raw = [
        ...fullYear(2024, mm: 1.0), // 366 giorni (bisestile) -> 366 mm
        ...fullYear(2025, mm: 2.0), // 365 giorni -> 730 mm
        for (var i = 0; i < 10; i++)
          day(DateTime(2026, 1, 1 + i), mm: 5.0),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.currentYear, 2026);
      expect(h.yearTotals.length, 2);
      expect(h.yearTotals[0].year, 2024);
      expect(h.yearTotals[0].millimeters, closeTo(366, 0.01));
      expect(h.yearTotals[1].millimeters, closeTo(730, 0.01));
    });

    test('cumulata anno corrente e ultima data disponibile', () {
      final raw = [
        ...fullYear(2025, mm: 1.0),
        for (var i = 0; i < 10; i++)
          day(DateTime(2026, 1, 1 + i), mm: 5.0),
        // Coda recente senza dato (ritardo ERA5): va ignorata.
        day(DateTime(2026, 1, 11)),
        day(DateTime(2026, 1, 12)),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.lastDataDate, DateTime(2026, 1, 10));
      expect(h.currentYearCumulative.length, 10);
      expect(h.currentYearCumulative.last.dayOfYear, 10);
      expect(h.currentYearCumulative.last.millimeters, closeTo(50, 0.01));
    });

    test('climatologia: media dei mesi nel periodo di riferimento', () {
      final raw = <RawDailyWeather>[
        // Gennaio 1991: 31 giorni da 1 mm = 31 mm.
        for (var d = 1; d <= 31; d++) day(DateTime(1991, 1, d), mm: 1.0),
        // Gennaio 1992: 31 giorni da 3 mm = 93 mm.
        for (var d = 1; d <= 31; d++) day(DateTime(1992, 1, d), mm: 3.0),
        day(DateTime(2026, 1, 1), mm: 0.0),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      // Media di gennaio = (31+93)/2 = 62; nessun altro mese ha dati,
      // quindi la cumulata resta piatta.
      expect(h.climatologyCumulative.length, 12);
      expect(h.climatologyCumulative[0], closeTo(62, 0.01));
      expect(h.climatologyCumulative[11], closeTo(62, 0.01));
    });

    test('giorni record in ordine decrescente', () {
      final raw = [
        ...fullYear(2025, mm: 1.0),
        day(DateTime(2026, 1, 1), mm: 120.0),
        day(DateTime(2026, 1, 2), mm: 80.0),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.topDays.length, HistoryAggregator.topDaysCount);
      expect(h.topDays[0].millimeters, 120.0);
      expect(h.topDays[0].date, DateTime(2026, 1, 1));
      expect(h.topDays[1].millimeters, 80.0);
    });
  });

  group('temperature', () {
    test('media annua, baseline e anni con copertura scarsa esclusi', () {
      final raw = [
        // Nel periodo baseline (1961-1990): due anni pieni a 11 e 13 °C.
        ...fullYear(1961, tMean: 11.0),
        ...fullYear(1962, tMean: 13.0),
        // Fuori baseline, più caldo.
        ...fullYear(2024, tMean: 15.0),
        // Anno con pochi dati: escluso dalla media annua.
        for (var d = 1; d <= 20; d++)
          day(DateTime(2000, 1, d), tMean: 10.0),
        day(DateTime(2026, 1, 1), mm: 0.0),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.annualMeanTemp.length, 3); // 1961, 1962, 2024 (non 2000)
      expect(h.annualMeanTemp[0].value, closeTo(11.0, 0.01));
      expect(h.baselineTemp, closeTo(12.0, 0.01)); // media 1961-62
      expect(
        h.annualMeanTemp.last.value - h.baselineTemp,
        closeTo(3.0, 0.01), // anomalia 2024
      );
    });

    test('baseline: ripiego sulla media di tutta la serie se scoperta', () {
      final raw = [
        ...fullYear(2023, tMean: 14.0),
        ...fullYear(2024, tMean: 16.0),
        day(DateTime(2026, 1, 1), mm: 0.0),
      ];

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.baselineTemp, closeTo(15.0, 0.01));
    });

    test('conteggio dei giorni molto caldi per anno', () {
      final raw = [
        // 2024: tutti i giorni a 18 °C tranne 12 a 32 °C.
        ...fullYear(2024, tMax: 18.0),
        // 2025: nessun giorno caldo.
        ...fullYear(2025, tMax: 20.0),
        day(DateTime(2026, 1, 1), mm: 0.0),
      ];
      // Sovrascrive 12 giorni di luglio 2024 con massime a 32 °C.
      for (var d = 0; d < 12; d++) {
        final idx = raw.indexWhere(
          (r) => r.date == DateTime(2024, 7, 1 + d),
        );
        raw[idx] = day(DateTime(2024, 7, 1 + d), tMax: 32.0);
      }

      final h = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      expect(h.hotDays.length, 2);
      expect(h.hotDays[0].year, 2024);
      expect(h.hotDays[0].value, 12);
      expect(h.hotDays[1].value, 0);
    });
  });

  group('WeatherHistory cache round-trip', () {
    test('serializza e riparsa senza perdite', () {
      final raw = [
        ...fullYear(2024, mm: 1.0, tMean: 13.0, tMax: 25.0),
        for (var i = 0; i < 5; i++)
          day(DateTime(2026, 1, 1 + i), mm: 2.0),
      ];
      final original = aggregator.aggregate(raw, fetchedAtUtc: fetchedAt);

      final restored = WeatherHistory.fromCacheJson(original.toCacheJson());

      expect(restored, isNotNull);
      expect(restored!.currentYear, original.currentYear);
      expect(restored.yearTotals.length, original.yearTotals.length);
      expect(
        restored.climatologyCumulative,
        original.climatologyCumulative,
      );
      expect(
        restored.currentYearCumulative.length,
        original.currentYearCumulative.length,
      );
      expect(restored.topDays.length, original.topDays.length);
      expect(restored.annualMeanTemp.length, original.annualMeanTemp.length);
      expect(restored.baselineTemp, original.baselineTemp);
      expect(restored.hotDays.length, original.hotDays.length);
      expect(restored.lastDataDate, original.lastDataDate);
      expect(restored.fetchedAtUtc, original.fetchedAtUtc);
    });
  });
}
