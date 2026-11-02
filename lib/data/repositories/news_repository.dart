import '../../domain/services/news_filter.dart';
import '../cache/news_cache.dart';
import '../datasources/news_datasource.dart';
import '../models/news_item.dart';

/// Esito del caricamento notizie.
class NewsResult {
  const NewsResult({
    required this.items,
    required this.fetchedAtUtc,
    required this.fromCache,
  });

  /// Notizie rilevanti per il bacino, ordinate dalla più recente.
  final List<NewsItem> items;

  final DateTime fetchedAtUtc;
  final bool fromCache;
}

/// Rete prima, cache come ripiego.
class NewsRepository {
  NewsRepository({
    required this.datasource,
    required this.cache,
    required this.filter,
  });

  final NewsDatasource datasource;
  final NewsCache cache;
  final NewsFilter filter;

  Future<NewsResult> load() async {
    try {
      final all = await datasource.fetchAll();
      final relevant = filter.relevant(all);
      final fetchedAt = DateTime.now().toUtc();
      await cache.save(relevant, fetchedAt);
      return NewsResult(
        items: relevant,
        fetchedAtUtc: fetchedAt,
        fromCache: false,
      );
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) {
        final (items, fetchedAt) = cached;
        return NewsResult(
          items: filter.relevant(items),
          fetchedAtUtc: fetchedAt,
          fromCache: true,
        );
      }
      rethrow;
    }
  }
}
