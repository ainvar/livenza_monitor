import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/regional_alert.dart';

/// Cache locale delle ultime allerte scaricate.
class AlertCache {
  static const _key = 'regional_alerts_v1';

  Future<void> save(List<RegionalAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final a in alerts) a.toCacheJson()]),
    );
  }

  Future<List<RegionalAlert>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! List) return null;
      return [
        for (final a in json)
          if (a is Map<String, dynamic>) ?RegionalAlert.fromCacheJson(a),
      ];
    } on FormatException {
      return null;
    }
  }
}
