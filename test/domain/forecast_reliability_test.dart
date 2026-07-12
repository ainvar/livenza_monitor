import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/datasources/ensemble_datasource.dart';
import 'package:livenza_monitor/domain/services/forecast_reliability.dart';

void main() {
  const service = ForecastReliability();

  /// Ensemble sintetico: 3 giorni interi, orari da mezzanotte.
  /// [rainyPerDay] indica, per ogni giorno, quanti membri prevedono
  /// pioggia (5 mm concentrati nella prima ora del giorno).
  EnsembleHourly build({required int members, required List<int> rainyPerDay}) {
    final times = <DateTime>[
      for (var d = 0; d < rainyPerDay.length; d++)
        for (var h = 0; h < 24; h++) DateTime(2026, 7, 10 + d, h),
    ];
    final series = <List<double>>[
      for (var m = 0; m < members; m++)
        [
          for (var d = 0; d < rainyPerDay.length; d++)
            for (var h = 0; h < 24; h++)
              (h == 0 && m < rainyPerDay[d]) ? 5.0 : 0.0,
        ],
    ];
    return EnsembleHourly(times: times, members: series);
  }

  group('compute', () {
    test('scenari tutti concordi -> 100%', () {
      final data = build(members: 40, rainyPerDay: [40, 0, 40]);
      final result =
          service.compute(data, now: DateTime(2026, 7, 10, 0, 30));

      expect(result.daily[DateTime(2026, 7, 10)], 100); // tutti pioggia
      expect(result.daily[DateTime(2026, 7, 11)], 100); // tutti asciutto
      expect(result.daily[DateTime(2026, 7, 12)], 100);
    });

    test('scenari divisi a metà -> 50%', () {
      final data = build(members: 40, rainyPerDay: [20, 30, 0]);
      final result =
          service.compute(data, now: DateTime(2026, 7, 10, 0, 30));

      expect(result.daily[DateTime(2026, 7, 10)], 50);
      expect(result.daily[DateTime(2026, 7, 11)], 75);
    });

    test('finestra 48h: percentuale calcolata sulle ore future', () {
      // Giorno 1 piovoso per 30/40 membri: la finestra 48h parte
      // dopo l'ora di pioggia del giorno 1, quindi conta solo i
      // giorni 2 (asciutto per tutti) e 3 (asciutto per tutti).
      final data = build(members: 40, rainyPerDay: [30, 0, 0]);
      final result =
          service.compute(data, now: DateTime(2026, 7, 10, 0, 30));

      expect(result.next48h, isNotNull);
      expect(result.next48h, 100);
    });

    test('giorni troncati esclusi, finestra corta -> null', () {
      // Solo 10 ore disponibili: né giorni completi né finestra 48h.
      final times = [
        for (var h = 0; h < 10; h++) DateTime(2026, 7, 10, h),
      ];
      final data = EnsembleHourly(
        times: times,
        members: [
          [for (var h = 0; h < 10; h++) 0.0],
        ],
      );
      final result = service.compute(data, now: DateTime(2026, 7, 10));

      expect(result.daily, isEmpty);
      expect(result.next48h, isNull);
    });
  });

  group('parseEnsembleHourly', () {
    test('raccoglie tutti i membri precipitation*', () {
      final data = parseEnsembleHourly({
        'hourly': {
          'time': ['2026-07-10T00:00', '2026-07-10T01:00'],
          'precipitation': [0.0, 1.5],
          'precipitation_member01': [0.2, null],
          'wind_speed': [10, 12],
        },
      });

      expect(data.times.length, 2);
      expect(data.members.length, 2);
      expect(data.members[0], [0.0, 1.5]);
      // null -> 0.
      expect(data.members[1], [0.2, 0.0]);
    });
  });
}
