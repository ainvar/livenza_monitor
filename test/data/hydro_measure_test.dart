import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/data/models/level_data.dart';

void main() {
  group('HydroMeasure.fromApiJson', () {
    test('parsa il payload reale dell\'API monitor', () {
      final m = HydroMeasure.fromApiJson(const {
        'station_name': 'Sacile',
        'station_id': 543,
        'sensor_id': 24,
        'dt': '2026-07-02 15:30:00',
        'value': 2.69,
      });

      expect(m, isNotNull);
      expect(m!.value, 2.69);
      // Il campo dt è UTC.
      expect(m.timestampUtc, DateTime.utc(2026, 7, 2, 15, 30));
    });

    test('valore mancante o non numerico -> null', () {
      expect(HydroMeasure.fromApiJson(const {'dt': '2026-07-02 15:30:00'}),
          isNull);
      expect(
        HydroMeasure.fromApiJson(
            const {'dt': '2026-07-02 15:30:00', 'value': 'n/d'}),
        isNull,
      );
      expect(HydroMeasure.fromApiJson(const {'value': 2.69}), isNull);
    });
  });

  group('LevelData cache round-trip', () {
    test('serializza e riparsa senza perdite', () {
      final data = LevelData(
        history: [
          HydroMeasure(
            timestampUtc: DateTime.utc(2026, 7, 2, 15),
            value: 2.68,
          ),
          HydroMeasure(
            timestampUtc: DateTime.utc(2026, 7, 2, 15, 15),
            value: 2.69,
          ),
        ],
        fetchedAtUtc: DateTime.utc(2026, 7, 2, 15, 20),
      );

      final restored = LevelData.fromCacheJson(data.toCacheJson());

      expect(restored, isNotNull);
      expect(restored!.history.length, 2);
      expect(restored.latest!.value, 2.69);
      expect(restored.fetchedAtUtc, data.fetchedAtUtc);
    });
  });
}
