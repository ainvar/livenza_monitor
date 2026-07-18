import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/regional_alert.dart';
import 'level_datasource.dart';

/// Sorgente delle allerte regionali del CFD.
abstract interface class CfdAlertDatasource {
  /// Le allerte emesse più recenti (nuova → vecchia).
  Future<List<RegionalAlert>> fetchRecentAlerts();
}

/// Implementazione sull'API pubblica del CFD
/// (https://cfd.protezionecivile.fvg.it/api/alerts).
class HttpCfdAlertDatasource implements CfdAlertDatasource {
  HttpCfdAlertDatasource(this._client);

  final http.Client _client;

  @override
  Future<List<RegionalAlert>> fetchRecentAlerts() async {
    final uri = Uri.parse('${AppConfig.cfdBaseUrl}/api/alerts')
        .replace(queryParameters: {'limit': '5'});

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(AppConfig.httpTimeout);

    if (response.statusCode != 200) {
      throw LevelDatasourceException('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['items'] is! List) {
      throw const LevelDatasourceException('Risposta API non valida');
    }

    return [
      for (final item in body['items'] as List)
        if (item is Map<String, dynamic>) ?RegionalAlert.fromApiJson(item),
    ];
  }
}
