import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../models/basin_station.dart';
import '../models/hydro_measure.dart';
import 'level_datasource.dart';

abstract interface class StationHistoryDatasource {
  Future<List<HydroMeasure>> fetchHistory(int stationId);
}

/// Scarica solo la stazione aperta, attraverso la stessa API della Home.
class MonitorStationHistoryDatasource implements StationHistoryDatasource {
  MonitorStationHistoryDatasource(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  @override
  Future<List<HydroMeasure>> fetchHistory(int stationId) async {
    if (!basinStations.any((station) => station.id == stationId)) {
      throw ArgumentError.value(stationId, 'stationId');
    }
    final now = _now().toUtc();
    final from = now.subtract(const Duration(hours: 48));
    final uri =
        Uri.parse(
          '${AppConfig.monitorBaseUrl}/stations/$stationId'
          '/sensors/${AppConfig.sacileHydroSensorId}/measures',
        ).replace(
          queryParameters: {
            'from': DateFormat('yyyy-MM-dd HH:mm:ss').format(from),
          },
        );
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConfig.httpTimeout);
    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['result'] != 'OK' ||
        body['measures'] is! List) {
      throw const LevelDatasourceException('Storico della stazione non valido');
    }
    final byTime = <DateTime, HydroMeasure>{};
    for (final raw in body['measures'] as List) {
      if (raw is! Map<String, dynamic>) continue;
      final measure = HydroMeasure.fromApiJson(raw);
      if (measure == null ||
          !measure.value.isFinite ||
          measure.timestampUtc.isBefore(from) ||
          measure.timestampUtc.isAfter(now)) {
        continue;
      }
      byTime[measure.timestampUtc] = measure;
    }
    return byTime.values.toList()
      ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
  }
}
