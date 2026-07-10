/// Notizia aggregata da un feed RSS locale.
class NewsItem {
  const NewsItem({
    required this.title,
    required this.link,
    required this.source,
    required this.publishedUtc,
    this.summary = '',
  });

  final String title;
  final String link;

  /// Nome della testata.
  final String source;

  final DateTime publishedUtc;

  /// Descrizione breve, già ripulita dall'HTML.
  final String summary;

  DateTime get publishedLocal => publishedUtc.toLocal();

  Map<String, dynamic> toCacheJson() => {
        't': title,
        'l': link,
        's': source,
        'p': publishedUtc.toIso8601String(),
        'd': summary,
      };

  static NewsItem? fromCacheJson(Map<String, dynamic> json) {
    final t = json['t'];
    final l = json['l'];
    final s = json['s'];
    final p = json['p'];
    if (t is! String || l is! String || s is! String || p is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(p);
    if (parsed == null) return null;
    return NewsItem(
      title: t,
      link: l,
      source: s,
      publishedUtc: parsed.toUtc(),
      summary: json['d'] is String ? json['d'] as String : '',
    );
  }
}
