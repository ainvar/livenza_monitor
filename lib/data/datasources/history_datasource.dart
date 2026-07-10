import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import 'level_datasource.dart';

/// Giorno della serie storica; i campi sono null se il dato
/// non è (ancora) disponibile.
typedef RawDailyWeather = ({
  DateTime date,
  double? precipitation,
  double? tMean,
  double? tMax,
});

/// Sorgente della serie storica giornaliera (pioggia e temperature).
abstract interface class HistoryDatasource {
  /// Scarica la serie completa dal 1940 a oggi (~31.000 giorni).
  Future<List<RawDailyWeather>> fetchDailySeries();
}

/// Implementazione sull'API archivio di Open-Meteo (rianalisi ERA5).
class OpenMeteoHistoryDatasource implements HistoryDatasource {
  OpenMeteoHistoryDatasource(this._client);

  final http.Client _client;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<List<RawDailyWeather>> fetchDailySeries() async {
    final today = DateTime.now();
    final uri = Uri.parse(AppConfig.openMeteoArchiveUrl).replace(
      queryParameters: {
        'latitude': '${AppConfig.sacileLat}',
        'longitude': '${AppConfig.sacileLon}',
        'start_date': '${AppConfig.historyStartYear}-01-01',
        'end_date': _dateFormat.format(today),
        'daily': 'precipitation_sum,temperature_2m_mean,temperature_2m_max',
        'timezone': 'Europe/Rome',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
      // La risposta è grande (~1.5 MB): timeout più generoso.
    ).timeout(AppConfig.httpTimeout * 4);

    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LevelDatasourceException('Risposta API non valida');
    }
    final daily = body['daily'];
    if (daily is! Map<String, dynamic>) {
      throw const LevelDatasourceException('Campo "daily" mancante');
    }
    final times = daily['time'];
    final precip = daily['precipitation_sum'];
    final tMean = daily['temperature_2m_mean'];
    final tMax = daily['temperature_2m_max'];
    if (times is! List ||
        precip is! List ||
        tMean is! List ||
        tMax is! List) {
      throw const LevelDatasourceException('Serie giornaliera mancante');
    }

    double? numAt(List list, int i) =>
        i < list.length && list[i] is num ? (list[i] as num).toDouble() : null;

    return [
      for (var i = 0; i < times.length; i++)
        if (times[i] is String)
          if (DateTime.tryParse(times[i] as String) case final d?)
            (
              date: d,
              precipitation: numAt(precip, i),
              tMean: numAt(tMean, i),
              tMax: numAt(tMax, i),
            ),
    ];
  }
}
