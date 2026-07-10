import '../../data/models/news_item.dart';

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

  List<NewsItem> relevant(List<NewsItem> items) =>
      [for (final i in items) if (isRelevant(i)) i];
}
