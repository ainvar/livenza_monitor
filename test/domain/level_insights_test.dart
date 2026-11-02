import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/domain/services/level_insights.dart';

void main() {
  const service = LevelInsights();
  final now = DateTime.utc(2026, 10, 14, 12);
  HydroMeasure at(int minutesAgo, double value) => HydroMeasure(
    timestampUtc: now.subtract(Duration(minutes: minutesAgo)),
    value: value,
  );

  test('livelli oltre 6,4 m restano compresi nel grafico', () {
    final range = service.chartRange([at(60, 6.9), at(0, 7.4)]);
    expect(range.min, lessThan(6.9));
    expect(range.max, greaterThan(7.4));
    expect(range.min, lessThan(range.max));
  });

  test('non attribuisce una variazione oraria a una serie troppo breve', () {
    expect(
      service.change([at(15, 2), at(0, 2.1)], const Duration(hours: 1)),
      isNull,
    );
  });

  test('non usa una misura distante dalla finestra richiesta', () {
    expect(
      service.change([at(360, 2), at(0, 2.1)], const Duration(hours: 1)),
      isNull,
    );
  });

  test('calcola separatamente variazioni oraria e sulle sei ore', () {
    final history = [at(360, 2), at(60, 2.3), at(0, 2.4)];
    expect(
      service.change(history, const Duration(hours: 1)),
      closeTo(.1, .00001),
    );
    expect(
      service.change(history, const Duration(hours: 6)),
      closeTo(.4, .00001),
    );
    expect(service.peak(history), same(history.last));
  });
}
