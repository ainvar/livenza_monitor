import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/cache/news_cache.dart';
import '../../data/datasources/news_datasource.dart';
import '../../data/repositories/news_repository.dart';
import '../../domain/services/news_filter.dart';
import 'level_providers.dart';

final newsDatasourceProvider = Provider<NewsDatasource>((ref) {
  return RssNewsDatasource(ref.watch(httpClientProvider));
});

final newsCacheProvider = Provider<NewsCache>((ref) => NewsCache());

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(
    datasource: ref.watch(newsDatasourceProvider),
    cache: ref.watch(newsCacheProvider),
    filter: const NewsFilter(),
  );
});

/// Notizie con refresh ogni 15 minuti (i feed cambiano lentamente).
class NewsNotifier extends AsyncNotifier<NewsResult> {
  @override
  Future<NewsResult> build() {
    final timer = Timer.periodic(
      AppConfig.refreshInterval * 3,
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    return ref.watch(newsRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(newsRepositoryProvider).load(),
    );
  }
}

final newsProvider = AsyncNotifierProvider<NewsNotifier, NewsResult>(
  NewsNotifier.new,
);
