import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/datasources/ensemble_datasource.dart';
import 'package:livenza_monitor/domain/services/scenario_analysis.dart';

void main() {
  const analysis = ScenarioAnalysis();
  final now = DateTime(2026, 7, 10, 0, 30);

  /// 48 ore future; ogni membro ha pioggia costante [mmPerHour].
  EnsembleHourly build(List<double> mmPerHour) {
    final times = [for (var h = 1; h <= 48; h++) DateTime(2026, 7, 10, h)];
    return EnsembleHourly(
      times: times,
      members: [
        for (final mm in mmPerHour) [for (var h = 0; h < 48; h++) mm],
      ],
    );
  }

  test('membri identici -> percentili coincidenti', () {
    final result = analysis.compute(build([0.5, 0.5, 0.5, 0.5]), now: now)!;

    expect(result.times.length, 48);
    expect(result.p10.last, closeTo(24, 0.01));
    expect(result.p50.last, closeTo(24, 0.01));
    expect(result.p90.last, closeTo(24, 0.01));
    expect(result.memberCount, 4);
  });

  test('percentili ordinati e mediana corretta con membri diversi', () {
    // Totali a 48h: 0, 48, 96, 144, 192.
    final result = analysis.compute(build([0, 1, 2, 3, 4]), now: now)!;

    expect(result.medianTotal, closeTo(96, 0.01));
    expect(result.dryTotal, lessThan(result.medianTotal));
    expect(result.wetTotal, greaterThan(result.medianTotal));
    // La cumulata cresce nel tempo.
    expect(result.p50.first, lessThan(result.p50.last));
  });

  test('probabilità di superamento delle soglie', () {
    // Totali: 0, 48, 96, 144, 192 -> >=20: 4/5, >=50: 3/5, >=100: 2/5.
    final result = analysis.compute(build([0, 1, 2, 3, 4]), now: now)!;

    expect(result.exceedanceProbability[20], 80);
    expect(result.exceedanceProbability[50], 60);
    expect(result.exceedanceProbability[100], 40);
  });

  test('dati futuri insufficienti -> null', () {
    final short = EnsembleHourly(
      times: [for (var h = 1; h <= 10; h++) DateTime(2026, 7, 10, h)],
      members: [
        [for (var h = 0; h < 10; h++) 0.0],
      ],
    );
    expect(analysis.compute(short, now: now), isNull);
  });

  test('riporta l’orizzonte effettivo e scarta membri incompleti', () {
    final original = build([0, 1, 2, 3, 4]);
    final members = [
      for (final m in original.members) [...m],
    ];
    members.last[30] = null;
    final result = analysis.compute(
      EnsembleHourly(times: original.times, members: members),
      now: now,
    )!;
    expect(result.horizonHours, 48);
    expect(result.totalMemberCount, 5);
    expect(result.memberCount, 4);
    expect(result.medianTotal, 72);
  });

  test('non presenta dati iniziati troppo avanti come prossime ore', () {
    expect(
      analysis.compute(build([0, 1, 2]), now: DateTime(2026, 7, 8)),
      isNull,
    );
  });
}
