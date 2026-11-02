import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livenza_monitor/data/datasources/ensemble_datasource.dart';
import 'package:livenza_monitor/data/repositories/ensemble_repository.dart';

class _Source implements EnsembleDatasource {
  int calls = 0;
  bool fail = false;
  Completer<EnsembleHourly>? pending;

  @override
  Future<EnsembleHourly> fetchHourlyPrecipitation() async {
    calls++;
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return EnsembleHourly(
      times: [DateTime(2026, 7, 10)],
      members: [
        [null],
        [1],
        [2],
      ],
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('forecast e scenari condividono la richiesta e la cache', () async {
    final source = _Source()..pending = Completer<EnsembleHourly>();
    final repository = EnsembleRepository(datasource: source, locationId: 543);
    final first = repository.load();
    final second = repository.load();
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 1);
    source.pending!.complete(
      EnsembleHourly(
        times: [DateTime(2026)],
        members: [
          [1],
        ],
      ),
    );
    expect(identical(await first, await second), isTrue);
    await repository.load();
    expect(source.calls, 1);
  });

  test(
    'cache persistente conserva lacune e resta separata per località',
    () async {
      final source = _Source();
      await EnsembleRepository(datasource: source, locationId: 543).load();
      source.fail = true;
      final restored = await EnsembleRepository(
        datasource: source,
        locationId: 543,
      ).load(force: true);
      expect(restored.isOfflineFallback, isTrue);
      expect(restored.data.members.first.first, isNull);
      await expectLater(
        EnsembleRepository(datasource: source, locationId: 188).load(),
        throwsStateError,
      );
    },
  );
}
