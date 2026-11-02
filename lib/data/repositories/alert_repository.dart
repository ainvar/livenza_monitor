import '../cache/alert_cache.dart';
import '../datasources/cfd_alert_datasource.dart';
import '../models/regional_alert.dart';

/// Esito del caricamento allerte.
class AlertResult {
  const AlertResult({
    required this.alerts,
    required this.fromCache,
    this.checkedAtUtc,
  });

  /// Allerte recenti emesse (nuova → vecchia).
  final List<RegionalAlert> alerts;

  final bool fromCache;
  final DateTime? checkedAtUtc;
}

/// Rete prima, cache come ripiego.
class AlertRepository {
  AlertRepository({required this.datasource, required this.cache});

  final CfdAlertDatasource datasource;
  final AlertCache cache;

  Future<AlertResult> load() async {
    try {
      final alerts = await datasource.fetchRecentAlerts();
      final checked = DateTime.now().toUtc();
      try {
        await cache.save(alerts, checkedAtUtc: checked);
      } catch (_) {
        // Un errore del disco non invalida i bollettini ricevuti dalla rete.
      }
      return AlertResult(
        alerts: alerts,
        fromCache: false,
        checkedAtUtc: checked,
      );
    } catch (_) {
      final cached = await cache.readSnapshot();
      if (cached != null) {
        return AlertResult(
          alerts: cached.alerts,
          fromCache: true,
          checkedAtUtc: cached.checkedAtUtc,
        );
      }
      rethrow;
    }
  }
}
