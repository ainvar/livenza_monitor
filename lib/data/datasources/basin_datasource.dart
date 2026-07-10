import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/basin_reading.dart';
import '../models/basin_station.dart';
import 'level_datasource.dart';

/// Sorgente delle ultime letture degli idrometri del bacino.
abstract interface class BasinDatasource {
  /// Scarica l'ultima misura di ogni stazione del bacino,
  /// nell'ordine di [basinStations].
  Future<List<BasinReading>> fetchLatestReadings();
}

/// Implementazione sull'API monitor: una sola chiamata restituisce
/// l'ultima misura di tutti gli idrometri della rete, poi si filtra
/// sulle stazioni curate del bacino.
class MonitorBasinDatasource implements BasinDatasource {
  MonitorBasinDatasource(this._client);

  final http.Client _client;

  @override
  Future<List<BasinReading>> fetchLatestReadings() async {
    final uri = Uri.parse(
      '${AppConfig.monitorBaseUrl}/sensors/${AppConfig.sacileHydroSensorId}'
      '/measures/latest',
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(AppConfig.httpTimeout);

    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['result'] != 'OK') {
      throw const LevelDatasourceException('Risposta API non valida');
    }

    final rawMeasures = body['measures'];
    if (rawMeasures is! List) {
      throw const LevelDatasourceException('Campo "measures" mancante');
    }

    // Indice per station_id delle misure ricevute.
    final byStationId = <int, Map<String, dynamic>>{};
    for (final m in rawMeasures) {
      if (m is Map<String, dynamic> && m['station_id'] is int) {
        byStationId[m['station_id'] as int] = m;
      }
    }

    return [
      for (final station in basinStations)
        if (byStationId[station.id] case final m?) ?_toReading(station, m),
    ];
  }

  BasinReading? _toReading(BasinStation station, Map<String, dynamic> m) {
    final dt = m['dt'];
    final value = m['value'];
    if (dt is! String || value is! num) return null;
    final parsed = DateTime.tryParse('${dt.replaceFirst(' ', 'T')}Z');
    if (parsed == null) return null;
    return BasinReading(
      station: station,
      value: value.toDouble(),
      timestampUtc: parsed,
    );
  }
}
