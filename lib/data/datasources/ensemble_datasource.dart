import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'level_datasource.dart';

/// Serie orarie di precipitazione dei membri dell'ensemble.
class EnsembleHourly {
  const EnsembleHourly({required this.times, required this.members});

  /// Orari (naive, fuso Europe/Rome come il resto del meteo).
  final List<DateTime> times;

  /// Una lista di valori orari (mm) per ciascun membro;
  /// tutte lunghe quanto [times].
  final List<List<double>> members;
}

/// Sorgente dei dati ensemble per l'affidabilità delle previsioni.
abstract interface class EnsembleDatasource {
  Future<EnsembleHourly> fetchHourlyPrecipitation();
}

/// Implementazione sull'API ensemble di Open-Meteo.
class OpenMeteoEnsembleDatasource implements EnsembleDatasource {
  OpenMeteoEnsembleDatasource(this._client);

  final http.Client _client;

  @override
  Future<EnsembleHourly> fetchHourlyPrecipitation() async {
    final uri = Uri.parse(AppConfig.openMeteoEnsembleUrl).replace(
      queryParameters: {
        'latitude': '${AppConfig.sacileLat}',
        'longitude': '${AppConfig.sacileLon}',
        'hourly': 'precipitation',
        'models': AppConfig.ensembleModel,
        'forecast_days': '7',
        'timezone': 'Europe/Rome',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(AppConfig.httpTimeout);

    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LevelDatasourceException('Risposta API non valida');
    }
    return parseEnsembleHourly(body);
  }
}

/// Parsa la risposta ensemble: la chiave `precipitation` e tutte le
/// `precipitation_memberXX` sono membri equivalenti.
EnsembleHourly parseEnsembleHourly(Map<String, dynamic> body) {
  final hourly = body['hourly'];
  if (hourly is! Map<String, dynamic>) {
    throw const LevelDatasourceException('Campo "hourly" mancante');
  }
  final rawTimes = hourly['time'];
  if (rawTimes is! List) {
    throw const LevelDatasourceException('Orari mancanti');
  }

  final times = <DateTime>[
    for (final t in rawTimes)
      if (t is String) ?DateTime.tryParse(t),
  ];

  final members = <List<double>>[];
  for (final key in hourly.keys) {
    if (!key.startsWith('precipitation')) continue;
    final values = hourly[key];
    if (values is! List || values.length < times.length) continue;
    members.add([
      for (var i = 0; i < times.length; i++)
        values[i] is num ? (values[i] as num).toDouble() : 0.0,
    ]);
  }

  if (times.isEmpty || members.isEmpty) {
    throw const LevelDatasourceException('Nessun membro ensemble');
  }
  return EnsembleHourly(times: times, members: members);
}
