import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_item.dart';

/// Cache locale delle ultime notizie filtrate.
class NewsCache {
  static const _key = 'news_items_v1';
  static const _fetchedAtKey = 'news_fetched_at_v1';

  Future<void> save(List<NewsItem> items, DateTime fetchedAtUtc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final i in items) i.toCacheJson()]),
    );
    await prefs.setString(_fetchedAtKey, fetchedAtUtc.toIso8601String());
  }

  Future<(List<NewsItem>, DateTime)?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final fetchedAtRaw = prefs.getString(_fetchedAtKey);
    if (raw == null || fetchedAtRaw == null) return null;
    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (fetchedAt == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! List) return null;
      final items = <NewsItem>[
        for (final i in json)
          if (i is Map<String, dynamic>) ?NewsItem.fromCacheJson(i),
      ];
      return (items, fetchedAt.toUtc());
    } on FormatException {
      return null;
    }
  }
}
