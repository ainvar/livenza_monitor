import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../../core/config/app_config.dart';
import '../models/osmer_bulletin.dart';
import 'level_datasource.dart';

/// Sorgente del bollettino di previsione ARPA-OSMER.
abstract interface class OsmerDatasource {
  Future<OsmerBulletin> fetchBulletin();
}

/// Implementazione sui file XML giornalieri di dev.meteo.fvg.it.
///
/// Il bollettino di oggi (`PW<oggi>.xml`) esce verso metà giornata:
/// se non c'è ancora, si ripiega su quello di ieri, che copre
/// comunque oggi e domani.
class XmlOsmerDatasource implements OsmerDatasource {
  XmlOsmerDatasource(this._client);

  final http.Client _client;

  static final _fileDate = DateFormat('yyyyMMdd');

  @override
  Future<OsmerBulletin> fetchBulletin() async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    Object? lastError;
    for (final date in [today, yesterday]) {
      final uri = Uri.parse(
        '${AppConfig.osmerForecastUrl}/PW${_fileDate.format(date)}.xml',
      );
      try {
        final response = await _client.get(uri).timeout(
              AppConfig.httpTimeout,
            );
        if (response.statusCode != 200) {
          lastError = LevelDatasourceException('HTTP ${response.statusCode}');
          continue;
        }
        return parseOsmerBulletin(response.body);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? const LevelDatasourceException('Bollettino assente');
  }
}

/// Parsa il bollettino, estraendo per ogni scadenza il testo della
/// zona di Sacile ([AppConfig.osmerZone], fallback "REGIONE").
OsmerBulletin parseOsmerBulletin(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException {
    throw const LevelDatasourceException('XML bollettino non valido');
  }

  final previsioni = document.findAllElements('previsioni').firstOrNull;
  if (previsioni == null) {
    throw const LevelDatasourceException('Bollettino senza previsioni');
  }

  final issued = _parseBulletinDate(_childText(previsioni, 'emissione')) ??
      DateTime.now().toUtc();
  final situazione =
      decodeOsmerText(_childText(previsioni, 'SITUAZIONEGENERALE_TESTO'));

  final days = <OsmerDay>[];
  for (final scadenza in document.findAllElements('scadenza')) {
    final date = _parseDate(scadenza.getAttribute('data_validita'));
    if (date == null) continue;
    final label = scadenza.getAttribute('giorno') ?? '';

    // Zona locale, con ripiego sul testo regionale.
    XmlElement? zone;
    XmlElement? regione;
    for (final z in scadenza.findAllElements('zona')) {
      if (z.getAttribute('nome') == AppConfig.osmerZone) zone = z;
      if (z.getAttribute('nome') == 'REGIONE') regione = z;
    }
    final chosen = _hasText(zone) ? zone : regione;
    if (chosen == null) continue;
    final text = decodeOsmerText(_childText(chosen, 'TESTO'));
    if (text.isEmpty) continue;

    final rawAtt = _childText(chosen, 'ATTENDIBILITA');
    days.add(
      OsmerDay(
        date: date,
        label: label,
        text: text,
        attendibilita: int.tryParse(rawAtt),
      ),
    );
  }

  if (days.isEmpty) {
    throw const LevelDatasourceException('Bollettino senza scadenze utili');
  }
  return OsmerBulletin(issuedUtc: issued, situazione: situazione, days: days);
}

bool _hasText(XmlElement? zone) =>
    zone != null && _childText(zone, 'TESTO').trim().isNotEmpty;

String _childText(XmlElement parent, String tag) {
  for (final el in parent.findElements(tag)) {
    return el.innerText.trim();
  }
  return '';
}

/// Data delle scadenze: "12-07-2026".
DateTime? _parseDate(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(raw);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
  );
}

/// Emissione: "11-07-2026 12:58:00 UTC".
DateTime? _parseBulletinDate(String raw) {
  final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})')
      .firstMatch(raw);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}

const _entities = <String, String>{
  '&agrave;': 'à', '&egrave;': 'è', '&eacute;': 'é', '&igrave;': 'ì', //
  '&ograve;': 'ò', '&ugrave;': 'ù', '&Agrave;': 'À', '&Egrave;': 'È',
  '&Eacute;': 'É', '&Igrave;': 'Ì', '&Ograve;': 'Ò', '&Ugrave;': 'Ù',
  '&deg;': '°', '&nbsp;': ' ', '&quot;': '"', '&apos;': "'",
  '&rsquo;': '’', '&lsquo;': '‘', '&amp;': '&',
};

/// I testi OSMER contengono entità HTML (es. "&igrave;") anche dopo
/// il parsing XML: le converte in caratteri.
String decodeOsmerText(String text) {
  var result = text;
  for (final e in _entities.entries) {
    result = result.replaceAll(e.key, e.value);
  }
  // Entità numeriche residue (es. &#039;).
  result = result.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}
