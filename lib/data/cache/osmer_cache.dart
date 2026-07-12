import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/osmer_bulletin.dart';

/// Cache locale dell'ultimo bollettino OSMER.
class OsmerCache {
  static const _key = 'osmer_bulletin_v1';

  Future<void> save(OsmerBulletin bulletin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(bulletin.toCacheJson()));
  }

  Future<OsmerBulletin?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return OsmerBulletin.fromCacheJson(json);
    } on FormatException {
      return null;
    }
  }
}
