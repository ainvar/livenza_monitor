import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livenza_monitor/data/datasources/basin_datasource.dart';
import 'package:livenza_monitor/data/models/basin_reading.dart';
import 'package:livenza_monitor/data/models/basin_station.dart';

void main() {
  group('MonitorBasinDatasource', () {
    test('filtra le stazioni curate e mantiene l\'ordine monte-valle',
        () async {
      // Payload con Sacile (543), Fiaschetti (58), una stazione fuori
      // bacino (1) e una misura malformata.
      final client = MockClient((request) async {
        expect(request.url.path, contains('/sensors/24/measures/latest'));
        return http.Response(
          jsonEncode({
            'result': 'OK',
            'measures': [
              {
                'station_name': 'Sacile',
                'station_id': 543,
                'dt': '2026-07-02 15:45:00',
                'value': 2.68,
              },
              {
                'station_name': 'Adegliacco',
                'station_id': 1,
                'dt': '2026-07-02 15:45:00',
                'value': 0.0,
              },
              {
                'station_name': 'Fiaschetti',
                'station_id': 58,
                'dt': '2026-07-02 15:45:00',
                'value': 1.63,
              },
              {'station_id': 121, 'dt': '2026-07-02 15:45:00'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final readings =
          await MonitorBasinDatasource(client).fetchLatestReadings();

      // Solo le 2 stazioni curate valide, ordinate da monte a valle
      // (Fiaschetti prima di Sacile).
      expect(readings.length, 2);
      expect(readings[0].station.id, 58);
      expect(readings[1].station.id, 543);
      expect(readings[1].value, 2.68);
      expect(readings[1].timestampUtc, DateTime.utc(2026, 7, 2, 15, 45));
    });
  });

  group('BasinData cache round-trip', () {
    test('serializza e riparsa scartando stazioni sconosciute', () {
      final sacile = basinStations.firstWhere((s) => s.isReference);
      final data = BasinData(
        readings: [
          BasinReading(
            station: sacile,
            value: 2.68,
            timestampUtc: DateTime.utc(2026, 7, 2, 15, 45),
          ),
        ],
        fetchedAtUtc: DateTime.utc(2026, 7, 2, 15, 50),
      );

      final json = data.toCacheJson();
      // Simula una stazione rimossa dalla lista curata.
      (json['readings'] as List).add({
        'id': 99999,
        'v': 1.0,
        't': '2026-07-02T15:45:00.000Z',
      });

      final restored = BasinData.fromCacheJson(json);

      expect(restored, isNotNull);
      expect(restored!.readings.length, 1);
      expect(restored.readings.single.station.id, sacile.id);
      expect(restored.newestMeasureUtc, DateTime.utc(2026, 7, 2, 15, 45));
    });
  });
}
