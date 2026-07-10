import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/basin_reading.dart';

/// Cache locale delle ultime letture del bacino.
class BasinCache {
  static const _key = 'basin_data_v1';

  Future<void> save(BasinData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toCacheJson()));
  }

  Future<BasinData?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return BasinData.fromCacheJson(json);
    } on FormatException {
      return null;
    }
  }
}
