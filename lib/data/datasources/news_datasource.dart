import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../core/config/app_config.dart';
import '../models/news_item.dart';
import 'level_datasource.dart';

/// Testata locale con feed RSS.
class NewsFeed {
  const NewsFeed({required this.name, required this.url});

  final String name;
  final String url;
}

/// Feed delle testate che coprono l'area di Sacile e del Livenza.
/// (Il sito del Comune di Sacile non espone RSS: piattaforma KPAX
/// con API interna non documentata — eventualmente via backend v2.)
const newsFeeds = <NewsFeed>[
  NewsFeed(name: 'Il Friuli', url: 'https://www.ilfriuli.it/rss.aspx'),
  NewsFeed(name: 'Nordest24', url: 'https://www.nordest24.it/feed'),
  NewsFeed(name: 'Il Popolo', url: 'https://www.ilpopolopordenone.it/feed'),
];

/// Sorgente delle notizie locali.
abstract interface class NewsDatasource {
  /// Scarica e unisce i feed; le testate irraggiungibili vengono
  /// saltate. Fallisce solo se nessun feed risponde.
  Future<List<NewsItem>> fetchAll();
}

/// Implementazione RSS (formato RSS 2.0).
class RssNewsDatasource implements NewsDatasource {
  RssNewsDatasource(this._client);

  final http.Client _client;

  @override
  Future<List<NewsItem>> fetchAll() async {
    final items = <NewsItem>[];
    var succeeded = 0;
    for (final feed in newsFeeds) {
      try {
        final response = await _client
            .get(
              Uri.parse(feed.url),
              headers: {
                'Accept': 'application/rss+xml, application/xml, text/xml',
                // Alcuni siti bloccano i client senza User-Agent.
                'User-Agent': 'LivenzaMonitor/0.1 (app civica; Android)',
              },
            )
            .timeout(AppConfig.httpTimeout);
        if (response.statusCode != 200) continue;
        items.addAll(parseRssItems(response.body, source: feed.name));
        succeeded++;
      } catch (_) {
        // Testata momentaneamente irraggiungibile: si prosegue.
      }
    }
    if (succeeded == 0) {
      throw const LevelDatasourceException('Nessun feed raggiungibile');
    }
    items.sort((a, b) => b.publishedUtc.compareTo(a.publishedUtc));
    return items;
  }
}

/// Parsa gli item di un feed RSS 2.0. Gli item malformati sono scartati.
List<NewsItem> parseRssItems(String xml, {required String source}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException {
    return const [];
  }

  final items = <NewsItem>[];
  for (final item in document.findAllElements('item')) {
    final title = _text(item, 'title');
    final link = _text(item, 'link');
    final pubDate = parseRfc822Date(_text(item, 'pubDate'));
    if (title.isEmpty || link.isEmpty || pubDate == null) continue;
    items.add(
      NewsItem(
        title: title,
        link: link,
        source: source,
        publishedUtc: pubDate,
        summary: _stripHtml(_text(item, 'description')),
      ),
    );
  }
  return items;
}

String _text(XmlElement parent, String tag) {
  for (final el in parent.findElements(tag)) {
    return el.innerText.trim();
  }
  return '';
}

/// Toglie tag HTML ed entità comuni dalle descrizioni dei feed.
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#8217;', "'")
      .replaceAll('&#8230;', '…')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Parsa una data RFC 822 dei feed RSS
/// (es. "Wed, 02 Jul 2026 18:30:00 +0200"). Restituisce UTC.
DateTime? parseRfc822Date(String input) {
  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{1,5})?',
  ).firstMatch(input);
  if (match == null) return null;

  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;

  final base = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );

  final zone = match.group(7);
  if (zone == null || zone == 'GMT' || zone == 'UT' || zone == 'UTC') {
    return base;
  }
  if (RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final hours = int.parse(zone.substring(1, 3));
    final minutes = int.parse(zone.substring(3, 5));
    return base.subtract(Duration(minutes: sign * (hours * 60 + minutes)));
  }
  // Sigle di fuso poco comuni: si assume UTC.
  return base;
}
