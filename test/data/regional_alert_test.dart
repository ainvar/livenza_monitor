import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/models/regional_alert.dart';
import 'package:livenza_monitor/domain/services/regional_alert_selector.dart';

/// Item nella forma reale dell'API /api/alerts del CFD.
Map<String, dynamic> _item({
  int number = 21,
  String status = 'emitted',
  String from = '2026-07-17T22:00:00.000Z',
  String to = '2026-07-18T21:59:00.000Z',
  int levelA = 1,
}) =>
    {
      'id': 649,
      'number': number,
      'status': status,
      'dt_emitted': '2026-07-17T10:30:00.000Z',
      'dt_from': from,
      'dt_to': to,
      'details': {
        'current_situation': 'Correnti <b>instabili</b>.',
        'weather_forecast': '<b>Sabato</b>: temporali.',
        'assessment': 'POSSIBILI CRISI LOCALI.',
        'operational_stage': 'ATTENZIONE',
      },
      'zones': {
        'fvgA': {
          'alert_level': levelA,
          'phenomenons': [
            {'type': 'temporali', 'value': 'temporali'},
            {'type': 'temporali', 'value': 'temporali localmente forti'},
            {'type': 'temporali', 'value': 'temporali'},
          ],
        },
        'fvgB': {'alert_level': 2, 'phenomenons': []},
      },
      'document_link': '/docs/alerts/2026/Allerta_regionale_21-2026.pdf',
      'full_name': 'Nome Operatore',
    };

void main() {
  group('RegionalAlert.fromApiJson', () {
    test('parsa livello e fenomeni della zona di Sacile (fvgA)', () {
      final a = RegionalAlert.fromApiJson(_item());

      expect(a, isNotNull);
      expect(a!.number, 21);
      expect(a.level, 1); // fvgA, non il 2 di fvgB
      expect(a.phenomena, ['temporali', 'temporali localmente forti']);
      expect(a.fromUtc, DateTime.utc(2026, 7, 17, 22));
      expect(a.situation, 'Correnti instabili.');
      expect(a.forecast, 'Sabato: temporali.');
      expect(a.operationalStage, 'ATTENZIONE');
      expect(
        a.documentUrl,
        'https://cfd.protezionecivile.fvg.it/docs/alerts/2026/Allerta_regionale_21-2026.pdf',
      );
    });

    test('allerta non emessa -> null', () {
      expect(RegionalAlert.fromApiJson(_item(status: 'draft')), isNull);
    });
  });

  group('RegionalAlertSelector', () {
    const selector = RegionalAlertSelector();

    test('allerta in corso ha precedenza su quella futura', () {
      final current = RegionalAlert.fromApiJson(_item(
        number: 20,
        from: '2026-07-16T22:00:00.000Z',
        to: '2026-07-17T21:59:00.000Z',
      ))!;
      final next = RegionalAlert.fromApiJson(_item(number: 21))!;

      final chosen = selector.select(
        [next, current],
        nowUtc: DateTime.utc(2026, 7, 17, 12),
      );

      expect(chosen!.number, 20);
    });

    test('senza allerta in corso sceglie la prossima', () {
      final next = RegionalAlert.fromApiJson(_item(number: 21))!;
      final chosen = selector.select(
        [next],
        nowUtc: DateTime.utc(2026, 7, 17, 12),
      );
      expect(chosen!.number, 21);
    });

    test('scarta scadute e zone non interessate', () {
      final expired = RegionalAlert.fromApiJson(_item(
        number: 19,
        from: '2026-07-10T22:00:00.000Z',
        to: '2026-07-11T21:59:00.000Z',
      ))!;
      final notMyZone = RegionalAlert.fromApiJson(_item(
        number: 22,
        levelA: 0,
      ))!;

      expect(
        selector.select(
          [expired, notMyZone],
          nowUtc: DateTime.utc(2026, 7, 17, 12),
        ),
        isNull,
      );
    });
  });

  group('cache round-trip', () {
    test('serializza e riparsa senza perdite', () {
      final original = RegionalAlert.fromApiJson(_item())!;
      final restored = RegionalAlert.fromCacheJson(original.toCacheJson());

      expect(restored, isNotNull);
      expect(restored!.number, original.number);
      expect(restored.level, original.level);
      expect(restored.phenomena, original.phenomena);
      expect(restored.fromUtc, original.fromUtc);
      expect(restored.toUtc, original.toUtc);
      expect(restored.documentUrl, original.documentUrl);
    });
  });
}
