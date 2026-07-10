import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_data.dart';

/// Cache locale dell'ultima serie di livelli scaricata con successo.
///
/// Permette di mostrare gli ultimi dati noti quando la rete non è
/// disponibile, marcandoli come "non aggiornati".
class LevelCache {
  static const _key = 'level_data_v1';

  Future<void> save(LevelData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toCacheJson()));
  }

  Future<LevelData?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return LevelData.fromCacheJson(json);
    } on FormatException {
      // Cache corrotta: la si ignora, verrà sovrascritta al prossimo fetch.
      return null;
    }
  }
}
