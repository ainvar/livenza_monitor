import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_data.dart';

/// Cache locale dell'ultimo meteo scaricato.
class WeatherCache {
  static const _key = 'weather_data_v1';

  Future<void> save(WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toCacheJson()));
  }

  Future<WeatherData?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return WeatherData.fromCacheJson(json);
    } on FormatException {
      return null;
    }
  }
}
