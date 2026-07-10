import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_history.dart';

/// Cache locale degli aggregati dello storico (pochi KB).
class HistoryCache {
  // v2: aggiunti gli aggregati di temperatura.
  static const _key = 'weather_history_v2';

  Future<void> save(WeatherHistory data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toCacheJson()));
  }

  Future<WeatherHistory?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return WeatherHistory.fromCacheJson(json);
    } on FormatException {
      return null;
    }
  }
}
