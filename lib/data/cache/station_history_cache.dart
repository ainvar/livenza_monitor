import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';

/// Una serie limitata a 48 ore per stazione; nessun archivio remoto.
class StationHistoryCache {
  String _key(int stationId) => 'station_history_${stationId}_v1';

  Future<void> save(int stationId, LevelData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(stationId), jsonEncode(data.toCacheJson()));
  }

  Future<LevelData?> read(int stationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(stationId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final data = LevelData.fromCacheJson(decoded);
      if (data == null) return null;
      final history = data.history.where((m) => m.value.isFinite).toList()
        ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
      return LevelData(history: history, fetchedAtUtc: data.fetchedAtUtc);
    } on FormatException {
      return null;
    }
  }
}
