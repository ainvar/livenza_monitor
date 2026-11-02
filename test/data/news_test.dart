import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/data/datasources/news_datasource.dart';
import 'package:livenza_monitor/data/models/news_item.dart';
import 'package:livenza_monitor/domain/services/news_filter.dart';

const _sampleRss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Testata di prova</title>
    <item>
      <title><![CDATA[Livenza in piena a Sacile, chiusi i parcheggi lungo il fiume]]></title>
      <link>https://esempio.it/livenza-piena</link>
      <pubDate>Wed, 02 Jul 2026 18:30:00 +0200</pubDate>
      <description><![CDATA[<p>Il fiume ha superato&nbsp;i livelli di guardia&#8230;</p>]]></description>
    </item>
    <item>
      <title>Nuova rotatoria a Codroipo</title>
      <link>https://esempio.it/rotatoria</link>
      <pubDate>Wed, 02 Jul 2026 10:00:00 GMT</pubDate>
      <description>Lavori in corso sulla statale.</description>
    </item>
    <item>
      <title>Notizia senza data</title>
      <link>https://esempio.it/no-date</link>
    </item>
  </channel>
</rss>
''';

void main() {
  group('parseRssItems', () {
    test('parsa titoli CDATA, date e descrizioni ripulite', () {
      final items = parseRssItems(_sampleRss, source: 'Prova');

      // La notizia senza data viene scartata.
      expect(items.length, 2);
      expect(items[0].title, contains('Livenza in piena a Sacile'));
      expect(items[0].source, 'Prova');
      // 18:30 +0200 -> 16:30 UTC.
      expect(items[0].publishedUtc, DateTime.utc(2026, 7, 2, 16, 30));
      // HTML e entità rimossi.
      expect(items[0].summary, 'Il fiume ha superato i livelli di guardia…');
      // GMT resta UTC.
      expect(items[1].publishedUtc, DateTime.utc(2026, 7, 2, 10));
    });

    test('xml non valido -> lista vuota', () {
      expect(parseRssItems('non è xml', source: 'X'), isEmpty);
    });
  });

  group('parseRfc822Date', () {
    test('offset negativo', () {
      expect(
        parseRfc822Date('Mon, 01 Dec 2025 08:15:30 -0500'),
        DateTime.utc(2025, 12, 1, 13, 15, 30),
      );
    });

    test('senza secondi e con giorno a una cifra', () {
      expect(
        parseRfc822Date('Tue, 3 Jun 2025 09:05 +0000'),
        DateTime.utc(2025, 6, 3, 9, 5),
      );
    });

    test('stringa non valida -> null', () {
      expect(parseRfc822Date('domani mattina'), isNull);
    });
  });

  group('NewsFilter', () {
    const filter = NewsFilter();

    NewsItem item(String title, [String summary = '']) => NewsItem(
      title: title,
      link: 'https://esempio.it',
      source: 'X',
      publishedUtc: DateTime.utc(2026),
      summary: summary,
    );

    test('tiene le notizie con località o fiumi del bacino', () {
      expect(filter.isRelevant(item('Piena del Livenza a SACILE')), isTrue);
      expect(
        filter.isRelevant(item('Lavori in centro', 'Il ponte sul Meschio')),
        isTrue,
      );
      expect(filter.isRelevant(item('Esondazione nella notte')), isTrue);
    });

    test('scarta le notizie non pertinenti', () {
      expect(filter.isRelevant(item('Nuova rotatoria a Codroipo')), isFalse);
      expect(
        filter.isRelevant(item('Il festival del cinema a Udine')),
        isFalse,
      );
    });

    test('le categorie includono titoli, sommari e temi sovrapposti', () {
      final news = item(
        'Sacile: il Comune chiude il ponte',
        'La pioggia fa salire il Livenza',
      );
      expect(filter.matchesTopic(news, NewsTopic.riverAndWeather), isTrue);
      expect(filter.matchesTopic(news, NewsTopic.townAndRoads), isTrue);
      expect(filter.matchesTopic(news, NewsTopic.all), isTrue);
      expect(
        filter.matchesTopic(item('Mostra a Sacile'), NewsTopic.riverAndWeather),
        isFalse,
      );
      expect(
        filter.matchesTopic(
          item('Livenza in crescita'),
          NewsTopic.riverAndWeather,
        ),
        isTrue,
      );
    });

    NewsItem article({
      required String link,
      String title = 'Maltempo a Sacile',
      String source = 'Testata A',
      int day = 3,
    }) => NewsItem(
      title: title,
      link: link,
      source: source,
      publishedUtc: DateTime.utc(2026, 7, day),
    );

    test('deduplica link con tracciamento e conserva la versione recente', () {
      final older = article(
        link: 'https://esempio.it/piena?utm_source=rss&id=42#lettura',
        day: 2,
      );
      final newer = article(
        link: 'https://esempio.it/piena?id=42&fbclid=abc',
        title: 'Titolo aggiornato a Sacile',
      );
      expect(filter.deduplicate([older, newer]), [newer]);
    });

    test('preserva notizie indipendenti con titoli uguali', () {
      final first = article(link: 'https://testataa.it/1');
      final second = article(
        link: 'https://testatab.it/2',
        source: 'Testata B',
      );
      expect(filter.deduplicate([first, second]), containsAll([first, second]));
    });

    test('accorpa il titolo nella stessa testata solo entro 48 ore', () {
      final newer = article(link: 'https://esempio.it/3', day: 5);
      final recentCopy = article(link: 'https://esempio.it/2', day: 4);
      final previousBulletin = article(link: 'https://esempio.it/1', day: 1);
      expect(filter.deduplicate([previousBulletin, recentCopy, newer]), [
        newer,
        previousBulletin,
      ]);
    });

    test('preserva parametri URL che identificano articoli diversi', () {
      final first = article(link: 'https://esempio.it/notizia?id=1');
      final second = article(
        link: 'https://esempio.it/notizia?id=2',
        title: 'Viabilità a Sacile',
      );
      expect(filter.deduplicate([first, second]), hasLength(2));
    });
  });
}
