import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/regional_alert.dart';

class CachedAlerts {
  const CachedAlerts(this.alerts, this.checkedAtUtc);
  final List<RegionalAlert> alerts;
  final DateTime? checkedAtUtc;
}

/// Cache locale delle ultime allerte scaricate.
class AlertCache {
  static const _key = 'regional_alerts_v1';

  Future<void> save(
    List<RegionalAlert> alerts, {
    DateTime? checkedAtUtc,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'checkedAt': (checkedAtUtc ?? DateTime.now().toUtc()).toIso8601String(),
        'alerts': [for (final a in alerts) a.toCacheJson()],
      }),
    );
  }

  Future<List<RegionalAlert>?> read() async => (await readSnapshot())?.alerts;

  Future<CachedAlerts?> readSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      // Le vecchie cache non hanno una data di verifica: resta sconosciuta.
      final rows = json is List ? json : (json is Map ? json['alerts'] : null);
      if (rows is! List) return null;
      final checked = json is Map ? json['checkedAt'] : null;
      return CachedAlerts([
        for (final a in rows)
          if (a is Map<String, dynamic>) ?RegionalAlert.fromCacheJson(a),
      ], checked is String ? DateTime.tryParse(checked)?.toUtc() : null);
    } on FormatException {
      return null;
    }
  }
}
