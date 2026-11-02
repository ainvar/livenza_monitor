import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/datasources/osmer_datasource.dart';
import 'package:livenza_monitor/data/models/osmer_bulletin.dart';

const _sampleXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<data id="meteo.fvg_previsioni_xml">
  <previsioni>
    <emissione>11-07-2026 12:58:00 UTC</emissione>
    <SITUAZIONEGENERALE_TESTO>L'anticiclone garantir&amp;agrave; stabilit&amp;agrave;.</SITUAZIONEGENERALE_TESTO>
    <scadenze>
      <scadenza id="1" data_validita="12-07-2026" giorno="DOMANI">
        <zone>
          <zona id="1" nome="REGIONE" descrizione="Regione">
            <ATTENDIBILITA um="%">80</ATTENDIBILITA>
            <TESTO>Testo regionale.</TESTO>
          </zona>
          <zona id="16" nome="Z2" descrizione="Alta_Pianura">
            <ATTENDIBILITA um="%">75</ATTENDIBILITA>
            <TESTO>Cielo sereno, far&amp;agrave; caldo, possibilit&amp;agrave; di temporali.</TESTO>
          </zona>
        </zone>
      </scadenza>
      <scadenza id="2" data_validita="13-07-2026" giorno="DOPODOMANI">
        <zone>
          <zona id="1" nome="REGIONE" descrizione="Regione">
            <ATTENDIBILITA um="%">60</ATTENDIBILITA>
            <TESTO>Variabile con rovesci sparsi.</TESTO>
          </zona>
          <zona id="16" nome="Z2" descrizione="Alta_Pianura">
            <ATTENDIBILITA um="%"></ATTENDIBILITA>
            <TESTO></TESTO>
          </zona>
        </zone>
      </scadenza>
    </scadenze>
  </previsioni>
</data>
''';

void main() {
  group('parseOsmerBulletin', () {
    test('estrae emissione, situazione e scadenze della zona Z2', () {
      final b = parseOsmerBulletin(_sampleXml);

      expect(b.issuedUtc, DateTime.utc(2026, 7, 11, 12, 58));
      expect(b.situazione, 'L\'anticiclone garantirà stabilità.');
      expect(b.days.length, 2);

      // Prima scadenza: usa la zona Z2 con la sua attendibilità.
      expect(b.days[0].date, DateTime(2026, 7, 12));
      expect(b.days[0].label, 'DOMANI');
      expect(
        b.days[0].text,
        'Cielo sereno, farà caldo, possibilità di temporali.',
      );
      expect(b.days[0].attendibilita, 75);

      // Seconda scadenza: Z2 vuota -> ripiego sul testo regionale.
      expect(b.days[1].text, 'Variabile con rovesci sparsi.');
      expect(b.days[1].attendibilita, 60);
    });

    test('xml non valido -> eccezione', () {
      expect(() => parseOsmerBulletin('non xml'), throwsA(anything));
    });
  });

  group('decodeOsmerText', () {
    test('decodifica entità HTML e normalizza gli spazi', () {
      expect(
        decodeOsmerText('pi&ugrave;  freddo &#039;domani&#039;\n al mattino'),
        "più freddo 'domani' al mattino",
      );
    });
  });

  group('OsmerBulletin cache round-trip', () {
    test('serializza e riparsa senza perdite', () {
      final original = parseOsmerBulletin(_sampleXml);

      final restored = OsmerBulletin.fromCacheJson(original.toCacheJson());

      expect(restored, isNotNull);
      expect(restored!.issuedUtc, original.issuedUtc);
      expect(restored.situazione, original.situazione);
      expect(restored.days.length, original.days.length);
      expect(restored.days[0].text, original.days[0].text);
      expect(restored.days[0].attendibilita, 75);
      expect(restored.days[1].attendibilita, 60);
    });
  });
}
