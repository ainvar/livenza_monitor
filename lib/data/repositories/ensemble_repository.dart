import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/ensemble_datasource.dart';

class EnsembleResult {
  const EnsembleResult({
    required this.data,
    required this.fetchedAtUtc,
    this.isOfflineFallback = false,
  });

  final EnsembleHourly data;
  final DateTime fetchedAtUtc;
  final bool isOfflineFallback;
}

/// Un solo download per punto, condiviso tra forecast e pagina scenari.
class EnsembleRepository {
  EnsembleRepository({required this.datasource, required this.locationId});

  static const maxAge = Duration(hours: 1);
  final EnsembleDatasource datasource;
  final int locationId;
  String get _key => 'ensemble_v1_$locationId';
  EnsembleResult? _cached;
  Future<EnsembleResult>? _pending;

  Future<EnsembleResult> load({bool force = false}) =>
      _pending ??= _load(force: force).whenComplete(() => _pending = null);

  Future<EnsembleResult> _load({required bool force}) async {
    _cached ??= await _read();
    final cached = _cached;
    if (!force && cached != null) {
      final age = DateTime.now().toUtc().difference(cached.fetchedAtUtc);
      if (!age.isNegative && age < maxAge) return cached;
    }
    try {
      final data = await datasource.fetchHourlyPrecipitation();
      final result = EnsembleResult(
        data: data,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      _cached = result;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _key,
          jsonEncode({
            'fetchedAt': result.fetchedAtUtc.toIso8601String(),
            'hourly': {
              'time': [for (final t in data.times) t.toIso8601String()],
              for (var i = 0; i < data.members.length; i++)
                'precipitation_member$i': data.members[i],
            },
          }),
        );
      } catch (_) {
        // La persistenza non deve nascondere dati validi.
      }
      return result;
    } catch (_) {
      if (cached != null) {
        return EnsembleResult(
          data: cached.data,
          fetchedAtUtc: cached.fetchedAtUtc,
          isOfflineFallback: true,
        );
      }
      rethrow;
    }
  }

  Future<EnsembleResult?> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['fetchedAt'] is! String) {
        return null;
      }
      final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String);
      if (fetchedAt == null) return null;
      return EnsembleResult(
        data: parseEnsembleHourly(json),
        fetchedAtUtc: fetchedAt.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}
