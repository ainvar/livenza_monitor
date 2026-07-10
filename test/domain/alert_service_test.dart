import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/domain/services/alert_service.dart';

void main() {
  const service = AlertService();

  group('classify', () {
    test('livello nullo -> unknown', () {
      expect(service.classify(null), AlertLevel.unknown);
    });

    test('sotto 5,5 m -> normale', () {
      expect(service.classify(2.69), AlertLevel.normal);
      expect(service.classify(5.49), AlertLevel.normal);
    });

    test('da 5,5 m -> allerta gialla', () {
      expect(service.classify(5.5), AlertLevel.yellow);
      expect(service.classify(5.99), AlertLevel.yellow);
    });

    test('da 6,0 m -> allerta rossa', () {
      expect(service.classify(6.0), AlertLevel.red);
      expect(service.classify(7.2), AlertLevel.red);
    });
  });

  group('trend', () {
    List<HydroMeasure> series(List<double> values) {
      // Misure ogni 15 minuti, l'ultima è "adesso".
      final now = DateTime.utc(2026, 7, 2, 12);
      return [
        for (final (i, v) in values.indexed)
          HydroMeasure(
            timestampUtc: now.subtract(
              Duration(minutes: 15 * (values.length - 1 - i)),
            ),
            value: v,
          ),
      ];
    }

    test('storia insufficiente -> unknown', () {
      expect(service.trend([]), LevelTrend.unknown);
      expect(service.trend(series([2.7])), LevelTrend.unknown);
    });

    test('variazione minima -> stabile', () {
      expect(
        service.trend(series([2.70, 2.70, 2.71, 2.71, 2.71])),
        LevelTrend.steady,
      );
    });

    test('salita oltre 3 cm in un\'ora -> in salita', () {
      expect(
        service.trend(series([2.70, 2.72, 2.75, 2.78, 2.81])),
        LevelTrend.rising,
      );
    });

    test('discesa oltre 3 cm in un\'ora -> in discesa', () {
      expect(
        service.trend(series([2.81, 2.78, 2.75, 2.72, 2.70])),
        LevelTrend.falling,
      );
    });
  });
}
