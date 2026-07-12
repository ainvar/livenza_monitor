/// Bollettino di previsione ARPA FVG — OSMER (meteo.fvg).
class OsmerBulletin {
  const OsmerBulletin({
    required this.issuedUtc,
    required this.situazione,
    required this.days,
  });

  /// Momento di emissione del bollettino (UTC).
  final DateTime issuedUtc;

  /// Testo della situazione generale.
  final String situazione;

  /// Scadenze di previsione (domani, dopodomani, ...).
  final List<OsmerDay> days;

  Map<String, dynamic> toCacheJson() => {
        'issued': issuedUtc.toIso8601String(),
        'situazione': situazione,
        'days': [for (final d in days) d.toCacheJson()],
      };

  static OsmerBulletin? fromCacheJson(Map<String, dynamic> json) {
    final issued = json['issued'];
    final situazione = json['situazione'];
    final days = json['days'];
    if (issued is! String || situazione is! String || days is! List) {
      return null;
    }
    final parsed = DateTime.tryParse(issued);
    if (parsed == null) return null;
    return OsmerBulletin(
      issuedUtc: parsed.toUtc(),
      situazione: situazione,
      days: [
        for (final d in days)
          if (d is Map<String, dynamic>) ?OsmerDay.fromCacheJson(d),
      ],
    );
  }
}

/// Previsione per un giorno, per la zona di Sacile.
class OsmerDay {
  const OsmerDay({
    required this.date,
    required this.label,
    required this.text,
    required this.attendibilita,
  });

  final DateTime date;

  /// Etichetta del bollettino (es. "DOMANI").
  final String label;

  /// Testo di previsione della zona.
  final String text;

  /// Attendibilità (%) dichiarata dai previsori, se presente.
  final int? attendibilita;

  Map<String, dynamic> toCacheJson() => {
        'date': date.toIso8601String(),
        'label': label,
        'text': text,
        if (attendibilita != null) 'att': attendibilita,
      };

  static OsmerDay? fromCacheJson(Map<String, dynamic> json) {
    final date = json['date'];
    final label = json['label'];
    final text = json['text'];
    if (date is! String || label is! String || text is! String) return null;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    return OsmerDay(
      date: parsed,
      label: label,
      text: text,
      attendibilita: json['att'] is num ? (json['att'] as num).round() : null,
    );
  }
}
