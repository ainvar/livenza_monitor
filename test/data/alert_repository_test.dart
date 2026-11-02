import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livenza_monitor/data/cache/alert_cache.dart';
import 'package:livenza_monitor/data/datasources/cfd_alert_datasource.dart';
import 'package:livenza_monitor/data/models/regional_alert.dart';
import 'package:livenza_monitor/data/repositories/alert_repository.dart';

class _Source implements CfdAlertDatasource {
  _Source({this.fails = false});
  final bool fails;
  @override
  Future<List<RegionalAlert>> fetchRecentAlerts() async {
    if (fails) throw StateError('Fonte non disponibile');
    return [];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'assenza di allerte verificata conserva la data del controllo',
    () async {
      final cache = AlertCache();
      final before = DateTime.now().toUtc();
      final result = await AlertRepository(
        datasource: _Source(),
        cache: cache,
      ).load();
      expect(result.fromCache, isFalse);
      expect(result.alerts, isEmpty);
      expect(result.checkedAtUtc!.isBefore(before), isFalse);
      expect((await cache.readSnapshot())!.checkedAtUtc, result.checkedAtUtc);
    },
  );

  test(
    'errore della fonte conserva la data precedente senza fingere una verifica',
    () async {
      final cache = AlertCache();
      final old = DateTime.utc(2026, 10, 13, 12);
      await cache.save([], checkedAtUtc: old);
      final result = await AlertRepository(
        datasource: _Source(fails: true),
        cache: cache,
      ).load();
      expect(result.fromCache, isTrue);
      expect(result.checkedAtUtc, old);
    },
  );

  test(
    'legge cache precedente senza inventare una data di controllo',
    () async {
      SharedPreferences.setMockInitialValues({
        'regional_alerts_v1': jsonEncode([]),
      });
      final cached = await AlertCache().readSnapshot();
      expect(cached, isNotNull);
      expect(cached!.alerts, isEmpty);
      expect(cached.checkedAtUtc, isNull);
    },
  );

  test('errore senza cache rimane distinto da nessuna allerta', () async {
    final repository = AlertRepository(
      datasource: _Source(fails: true),
      cache: AlertCache(),
    );
    await expectLater(repository.load(), throwsStateError);
  });
}
