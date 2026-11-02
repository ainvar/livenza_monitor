import '../../core/config/app_config.dart';

/// Allerta regionale emessa dal CFD della Protezione Civile FVG,
/// letta per la zona di allertamento di Sacile.
class RegionalAlert {
  const RegionalAlert({
    required this.number,
    required this.emittedUtc,
    required this.fromUtc,
    required this.toUtc,
    required this.level,
    required this.phenomena,
    required this.situation,
    required this.forecast,
    required this.assessment,
    required this.operationalStage,
    required this.documentUrl,
  });

  /// Numero progressivo dell'allerta nell'anno.
  final int number;

  final DateTime emittedUtc;
  final DateTime fromUtc;
  final DateTime toUtc;

  /// Livello per la zona di Sacile: 0 = non interessata,
  /// 1 = gialla, 2 = arancione, 3 = rossa.
  final int level;

  /// Fenomeni previsti per la zona (es. "temporali localmente forti").
  final List<String> phenomena;

  final String situation;
  final String forecast;
  final String assessment;
  final String operationalStage;

  /// URL assoluto del documento ufficiale (PDF).
  final String documentUrl;

  bool isActiveAt(DateTime nowUtc) =>
      !nowUtc.isBefore(fromUtc) && !nowUtc.isAfter(toUtc);

  bool isUpcomingAt(DateTime nowUtc) => nowUtc.isBefore(fromUtc);

  /// Parsa un item dell'API `/api/alerts`. Restituisce null se
  /// mancano i campi essenziali o l'allerta non è emessa.
  static RegionalAlert? fromApiJson(Map<String, dynamic> json) {
    if (json['status'] != 'emitted') return null;
    final number = json['number'];
    final emitted = _date(json['dt_emitted']);
    final from = _date(json['dt_from']);
    final to = _date(json['dt_to']);
    if (number is! int || emitted == null || from == null || to == null) {
      return null;
    }

    // Livello e fenomeni della zona di Sacile.
    var level = 0;
    final phenomena = <String>[];
    final zones = json['zones'];
    if (zones is Map<String, dynamic>) {
      final zone = zones[AppConfig.alertZoneKey];
      if (zone is Map<String, dynamic>) {
        if (zone['alert_level'] is num) {
          level = (zone['alert_level'] as num).round();
        }
        final raw = zone['phenomenons'];
        if (raw is List) {
          for (final p in raw) {
            if (p is Map<String, dynamic> && p['value'] is String) {
              final value = p['value'] as String;
              if (!phenomena.contains(value)) phenomena.add(value);
            }
          }
        }
      }
    }

    final details = json['details'] is Map<String, dynamic>
        ? json['details'] as Map<String, dynamic>
        : const <String, dynamic>{};
    String text(String key) =>
        details[key] is String ? stripAlertHtml(details[key] as String) : '';

    final documentLink = json['document_link'];

    return RegionalAlert(
      number: number,
      emittedUtc: emitted,
      fromUtc: from,
      toUtc: to,
      level: level,
      phenomena: phenomena,
      situation: text('current_situation'),
      forecast: text('weather_forecast'),
      assessment: text('assessment'),
      operationalStage: text('operational_stage'),
      documentUrl: documentLink is String && documentLink.isNotEmpty
          ? '${AppConfig.cfdBaseUrl}$documentLink'
          : '',
    );
  }

  static DateTime? _date(dynamic raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  Map<String, dynamic> toCacheJson() => {
    'n': number,
    'e': emittedUtc.toIso8601String(),
    'f': fromUtc.toIso8601String(),
    't': toUtc.toIso8601String(),
    'l': level,
    'p': phenomena,
    'si': situation,
    'fo': forecast,
    'as': assessment,
    'st': operationalStage,
    'doc': documentUrl,
  };

  static RegionalAlert? fromCacheJson(Map<String, dynamic> json) {
    final n = json['n'];
    final e = _date(json['e']);
    final f = _date(json['f']);
    final t = _date(json['t']);
    final l = json['l'];
    if (n is! int || e == null || f == null || t == null || l is! int) {
      return null;
    }
    return RegionalAlert(
      number: n,
      emittedUtc: e,
      fromUtc: f,
      toUtc: t,
      level: l,
      phenomena: [
        if (json['p'] is List)
          for (final p in json['p'] as List)
            if (p is String) p,
      ],
      situation: json['si'] is String ? json['si'] as String : '',
      forecast: json['fo'] is String ? json['fo'] as String : '',
      assessment: json['as'] is String ? json['as'] as String : '',
      operationalStage: json['st'] is String ? json['st'] as String : '',
      documentUrl: json['doc'] is String ? json['doc'] as String : '',
    );
  }
}

/// Toglie i tag HTML presenti nei testi del CFD (es. `<b>`).
String stripAlertHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      // Niente spazi orfani prima della punteggiatura.
      .replaceAllMapped(RegExp(r'\s+([.,;:!?])'), (m) => m.group(1)!)
      .trim();
}
