import '../cache/alert_cache.dart';
import '../datasources/cfd_alert_datasource.dart';
import '../models/regional_alert.dart';

/// Esito del caricamento allerte.
class AlertResult {
  const AlertResult({required this.alerts, required this.fromCache});

  /// Allerte recenti emesse (nuova → vecchia).
  final List<RegionalAlert> alerts;

  final bool fromCache;
}

/// Rete prima, cache come ripiego.
class AlertRepository {
  AlertRepository({required this.datasource, required this.cache});

  final CfdAlertDatasource datasource;
  final AlertCache cache;

  Future<AlertResult> load() async {
    try {
      final alerts = await datasource.fetchRecentAlerts();
      await cache.save(alerts);
      return AlertResult(alerts: alerts, fromCache: false);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) {
        return AlertResult(alerts: cached, fromCache: true);
      }
      rethrow;
    }
  }
}
