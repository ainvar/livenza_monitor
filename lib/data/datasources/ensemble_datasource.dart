import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/weather_location.dart';
import 'level_datasource.dart';

/// Serie orarie di precipitazione dei membri dell'ensemble.
class EnsembleHourly {
  const EnsembleHourly({required this.times, required this.members});

  /// Orari (naive, fuso Europe/Rome come il resto del meteo).
  final List<DateTime> times;

  /// Una lista di valori orari (mm) per ciascun membro;
  /// tutte lunghe quanto [times].
  final List<List<double?>> members;

  /// Usa solo membri interamente disponibili nella finestra: una lacuna
  /// non significa assenza di pioggia. Servono almeno 3 membri e l'80%
  /// dell'ensemble ricevuto per evitare percentuali da pochi scenari.
  List<List<double>> completeMembers(List<int> indices) {
    final valid = <List<double>>[
      for (final member in members)
        if (indices.every(
          (i) =>
              i < member.length &&
              member[i] != null &&
              member[i]!.isFinite &&
              member[i]! >= 0,
        ))
          [for (final i in indices) member[i]!],
    ];
    if (valid.length < 3 || valid.length < members.length * 0.8) return [];
    return valid;
  }
}

/// Sorgente dei dati ensemble per l'affidabilità delle previsioni.
abstract interface class EnsembleDatasource {
  Future<EnsembleHourly> fetchHourlyPrecipitation();
}

/// Implementazione sull'API ensemble di Open-Meteo.
class OpenMeteoEnsembleDatasource implements EnsembleDatasource {
  OpenMeteoEnsembleDatasource(
    this._client, {
    this.location = WeatherLocation.sacile,
  });

  final http.Client _client;
  final WeatherLocation location;

  @override
  Future<EnsembleHourly> fetchHourlyPrecipitation() async {
    final uri = Uri.parse(AppConfig.openMeteoEnsembleUrl).replace(
      queryParameters: {
        'latitude': '${location.lat}',
        'longitude': '${location.lon}',
        'hourly': 'precipitation',
        'models': AppConfig.ensembleModel,
        'forecast_days': '7',
        'timezone': 'Europe/Rome',
      },
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConfig.httpTimeout);

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

  // Mantiene l'indice originale: scartare un orario non deve spostare
  // i valori delle ore successive. Ordina e rimuove orari duplicati.
  final indexedTimes = <({int index, DateTime time})>[
    for (var i = 0; i < rawTimes.length; i++)
      if (rawTimes[i] is String)
        if (DateTime.tryParse(rawTimes[i] as String) case final time?)
          (index: i, time: time),
  ]..sort((a, b) => a.time.compareTo(b.time));
  final seen = <DateTime>{};
  final entries = indexedTimes.where((e) => seen.add(e.time)).toList();
  final times = [for (final entry in entries) entry.time];

  final members = <List<double?>>[];
  for (final key in hourly.keys) {
    if (!RegExp(r'^precipitation(?:_member\d+)?$').hasMatch(key)) continue;
    final values = hourly[key];
    if (values is! List) continue;
    members.add([
      for (final entry in entries)
        if (entry.index < values.length &&
            values[entry.index] is num &&
            (values[entry.index] as num).isFinite &&
            (values[entry.index] as num) >= 0)
          (values[entry.index] as num).toDouble()
        else
          null,
    ]);
  }

  if (times.isEmpty || members.isEmpty) {
    throw const LevelDatasourceException('Nessun membro ensemble');
  }
  return EnsembleHourly(times: times, members: members);
}
