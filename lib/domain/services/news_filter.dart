import '../../data/models/news_item.dart';

enum NewsTopic {
  all('Tutte'),
  riverAndWeather('Fiume e meteo'),
  townAndRoads('Comune e viabilità');

  const NewsTopic(this.label);
  final String label;
}

/// Filtra le notizie regionali tenendo solo quelle rilevanti per
/// Sacile e il bacino del Livenza.
class NewsFilter {
  const NewsFilter();

  /// Località e corsi d'acqua del bacino, più i termini di piena.
  /// Il confronto è case-insensitive su titolo + sommario.
  static const keywords = <String>[
    // Località del bacino
    'sacile', 'caneva', 'polcenigo', 'budoia', 'brugnera',
    'fontanafredda', 'pasiano', 'prata di pordenone', 'porcia',
    'pravisdomini', 'cordignano',
    // Corsi d'acqua e territorio
    'livenza', 'meschio', 'meduna', 'cellina', 'noncello', 'cansiglio',
    // Eventi rilevanti per l'app
    'esondazion', 'alluvion', 'piena dei fiumi', 'rischio idraulico',
    'allerta meteo fvg',
  ];

  bool isRelevant(NewsItem item) {
    final text = '${item.title} ${item.summary}'.toLowerCase();
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  /// Classificazione editoriale indicativa, non una verifica della notizia
  /// né dell'ufficialità della fonte. Una notizia può avere entrambi i temi.
  bool matchesTopic(NewsItem item, NewsTopic topic) {
    if (topic == NewsTopic.all) return true;
    final text = '${item.title} ${item.summary}'.toLowerCase();
    return switch (topic) {
      NewsTopic.all => true,
      NewsTopic.riverAndWeather => RegExp(
        r'\b(fium[ei]|livenza|meschio|meduna|cellina|noncello|'
        r'meteo|piogg|precipitazion|temporal|nubifrag|'
        r'alluvion|esondazion|allagament|idraulic|idrogeologic|'
        r'argine|argini|siccità|maltempo|piena\b|piene\b)',
      ).hasMatch(text),
      NewsTopic.townAndRoads => RegExp(
        r'\b(comune|comunale|comunali|municip|sindac|ordinanz|'
        r'viabil|traffic|strad|ponte|ponti|chius|chiud|chiusur|'
        r'parchegg|deviazion|transito|cantier|lavori pubblici)',
      ).hasMatch(text),
    };
  }

  List<NewsItem> relevant(List<NewsItem> items) => deduplicate([
    for (final i in items)
      if (isRelevant(i)) i,
  ]);

  /// Conserva la versione più recente dello stesso link. Titoli identici
  /// vengono accorpati solo nella stessa testata ed entro 48 ore, per non
  /// nascondere articoli indipendenti o bollettini di giorni diversi.
  List<NewsItem> deduplicate(List<NewsItem> items) {
    final sorted = [...items]
      ..sort((a, b) => b.publishedUtc.compareTo(a.publishedUtc));
    final urls = <String>{};
    final titles = <String, DateTime>{};
    final result = <NewsItem>[];
    for (final item in sorted) {
      final url = _canonicalUrl(item.link);
      final title = item.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), ' ')
          .trim();
      final titleKey = '${item.source.trim().toLowerCase()}|$title';
      final previous = titles[titleKey];
      final repeatedTitle =
          title.isNotEmpty &&
          previous != null &&
          previous.difference(item.publishedUtc).abs() <=
              const Duration(hours: 48);
      final repeatedUrl = url.isNotEmpty && !urls.add(url);
      if (repeatedUrl || repeatedTitle) continue;
      titles[titleKey] = item.publishedUtc;
      result.add(item);
    }
    return result;
  }

  String _canonicalUrl(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || !uri.hasAuthority) return link.trim();
    final keys = uri.queryParametersAll.keys.where((key) {
      final lower = key.toLowerCase();
      return !lower.startsWith('utm_') &&
          !const {
            'fbclid',
            'gclid',
            'dclid',
            'mc_cid',
            'mc_eid',
          }.contains(lower);
    }).toList()..sort();
    return Uri(
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
      queryParameters: keys.isEmpty
          ? null
          : {for (final key in keys) key: uri.queryParametersAll[key]!},
    ).toString();
  }
}
