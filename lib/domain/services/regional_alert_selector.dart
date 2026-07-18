import '../../data/models/regional_alert.dart';

/// Sceglie quale allerta mostrare per la zona di Sacile. Logica pura.
class RegionalAlertSelector {
  const RegionalAlertSelector();

  /// Restituisce l'allerta da mostrare, oppure null se non ce ne sono
  /// di rilevanti: si considera solo la zona di Sacile (livello > 0)
  /// e si scarta ciò che è già scaduto. Ha precedenza l'allerta in
  /// corso; altrimenti la prossima in ordine di inizio.
  RegionalAlert? select(List<RegionalAlert> alerts, {required DateTime nowUtc}) {
    RegionalAlert? active;
    RegionalAlert? upcoming;
    for (final alert in alerts) {
      if (alert.level <= 0) continue;
      if (alert.toUtc.isBefore(nowUtc)) continue;
      if (alert.isActiveAt(nowUtc)) {
        if (active == null || alert.number > active.number) {
          active = alert;
        }
      } else if (alert.isUpcomingAt(nowUtc)) {
        if (upcoming == null || alert.fromUtc.isBefore(upcoming.fromUtc)) {
          upcoming = alert;
        }
      }
    }
    return active ?? upcoming;
  }
}
