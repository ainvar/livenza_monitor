import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../models/hydro_measure.dart';

/// Sorgente dei livelli idrometrici.
///
/// Astrazione che permette di passare dalle chiamate dirette all'API
/// della Protezione Civile FVG al futuro backend Cloudflare senza
/// toccare repository e UI (vedi [AppConfig.useBackend]).
abstract interface class LevelDatasource {
  /// Scarica le misure dalle ultime [window] a ora, ordinate per tempo.
  Future<List<HydroMeasure>> fetchHistory({required Duration window});
}

/// Implementazione diretta sull'API monitor della Protezione Civile FVG.
class MonitorLevelDatasource implements LevelDatasource {
  MonitorLevelDatasource(this._client);

  final http.Client _client;

  // Formato data/ora UTC richiesto dal parametro `from` dell'API.
  static final _dtFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Future<List<HydroMeasure>> fetchHistory({required Duration window}) async {
    final from = DateTime.now().toUtc().subtract(window);
    final uri = Uri.parse(
      '${AppConfig.monitorBaseUrl}/stations/${AppConfig.sacileStationId}'
      '/sensors/${AppConfig.sacileHydroSensorId}/measures',
    ).replace(queryParameters: {'from': _dtFormat.format(from)});

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConfig.httpTimeout);

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

    final measures = <HydroMeasure>[
      for (final m in rawMeasures)
        if (m is Map<String, dynamic>) ?HydroMeasure.fromApiJson(m),
    ]..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));

    return measures;
  }
}

class LevelDatasourceException implements Exception {
  const LevelDatasourceException(this.message);

  final String message;

  @override
  String toString() => 'LevelDatasourceException: $message';
}
