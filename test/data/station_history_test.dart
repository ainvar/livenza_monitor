import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livenza_monitor/data/cache/station_history_cache.dart';
import 'package:livenza_monitor/data/datasources/level_datasource.dart';
import 'package:livenza_monitor/data/datasources/station_history_datasource.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/data/models/level_data.dart';
import 'package:livenza_monitor/data/repositories/station_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);
  final data = LevelData(
    history: [HydroMeasure(timestampUtc: now, value: 2.7)],
    fetchedAtUtc: now,
  );

  group('MonitorStationHistoryDatasource', () {
    test(
      'richiede 48 ore in UTC e ordina le misure valide senza duplicati',
      () async {
        final datasource = MonitorStationHistoryDatasource(
          MockClient((request) async {
            expect(
              request.url.path,
              endsWith('/stations/58/sensors/24/measures'),
            );
            expect(request.url.queryParameters['from'], '2026-10-12 12:00:00');
            return http.Response(
              jsonEncode({
                'result': 'OK',
                'measures': [
                  {'dt': '2026-10-14 12:00:00', 'value': 2.7},
                  {'dt': '2026-10-14 10:00:00', 'value': 2.5},
                  {'dt': '2026-10-14 10:00:00', 'value': 2.6},
                  {'dt': '2026-10-12 11:59:59', 'value': 1.0},
                  {'dt': '2026-10-14 12:00:01', 'value': 9.0},
                  {'dt': 'non valido', 'value': 1.0},
                  {'dt': '2026-10-14 11:00:00'},
                  null,
                ],
              }),
              200,
            );
          }),
          now: () => now,
        );
        final measures = await datasource.fetchHistory(58);
        expect(measures.map((m) => m.value), [2.6, 2.7]);
        expect(measures.first.timestampUtc, DateTime.utc(2026, 10, 14, 10));
        expect(measures.every((m) => m.timestampUtc.isUtc), isTrue);
      },
    );

    test(
      'rifiuta stazioni sconosciute prima di effettuare la richiesta',
      () async {
        final datasource = MonitorStationHistoryDatasource(
          MockClient((_) async {
            fail('Non deve effettuare richieste per stazioni sconosciute');
          }),
        );
        await expectLater(datasource.fetchHistory(-1), throwsArgumentError);
      },
    );

    test('risposte errate non diventano uno storico vuoto', () async {
      for (final payload in [
        {'result': 'ERROR', 'measures': []},
        {'result': 'OK'},
      ]) {
        final datasource = MonitorStationHistoryDatasource(
          MockClient((_) async => http.Response(jsonEncode(payload), 200)),
        );
        await expectLater(
          datasource.fetchHistory(58),
          throwsA(isA<LevelDatasourceException>()),
        );
      }
    });
  });

  group('StationHistoryRepository', () {
    test('mantiene dati appena scaricati se il salvataggio fallisce', () async {
      final repository = StationHistoryRepository(
        datasource: _HistoryDatasource(data.history),
        cache: _MemoryCache()..failSave = true,
      );
      final result = await repository.load(58);
      expect(result.data.latest?.value, 2.7);
      expect(result.fromCache, isFalse);
    });

    test('usa la cache in assenza di rete indicando la sua origine', () async {
      final repository = StationHistoryRepository(
        datasource: _HistoryDatasource(null),
        cache: _MemoryCache()..stored = data,
      );
      final result = await repository.load(58);
      expect(result.data, same(data));
      expect(result.fromCache, isTrue);
    });

    test(
      'risposta vuota non viene sostituita con una vecchia misura',
      () async {
        final cache = _MemoryCache()..stored = data;
        final repository = StationHistoryRepository(
          datasource: _HistoryDatasource([]),
          cache: cache,
        );
        final result = await repository.load(58);
        expect(result.data.isEmpty, isTrue);
        expect(result.fromCache, isFalse);
        expect(cache.stored, same(data));
      },
    );

    test('senza rete e senza cache propaga l’errore della fonte', () async {
      final repository = StationHistoryRepository(
        datasource: _HistoryDatasource(null),
        cache: _MemoryCache(),
      );
      await expectLater(
        repository.load(58),
        throwsA(isA<LevelDatasourceException>()),
      );
    });
  });

  group('StationHistoryCache', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'salva ogni stazione separatamente e mantiene gli istanti UTC',
      () async {
        final cache = StationHistoryCache();
        await cache.save(58, data);
        expect((await cache.read(58))?.latest?.timestampUtc, now);
        expect((await cache.read(58))?.latest?.value, 2.7);
        expect(await cache.read(543), isNull);
      },
    );

    test('una cache danneggiata viene ignorata', () async {
      SharedPreferences.setMockInitialValues({
        'station_history_58_v1': 'non json',
      });
      expect(await StationHistoryCache().read(58), isNull);
    });
  });
}

class _HistoryDatasource implements StationHistoryDatasource {
  _HistoryDatasource(this.history);
  final List<HydroMeasure>? history;

  @override
  Future<List<HydroMeasure>> fetchHistory(int stationId) async {
    if (history == null) throw const LevelDatasourceException('Rete assente');
    return history!;
  }
}

class _MemoryCache extends StationHistoryCache {
  LevelData? stored;
  bool failSave = false;

  @override
  Future<LevelData?> read(int stationId) async => stored;

  @override
  Future<void> save(int stationId, LevelData data) async {
    if (failSave) throw StateError('Persistenza non disponibile');
    stored = data;
  }
}
