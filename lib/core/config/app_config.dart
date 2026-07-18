/// Configurazione globale dell'app.
///
/// Centralizza endpoint, intervalli e costanti così che il passaggio
/// dalle chiamate dirette alle API verso il backend Cloudflare richieda
/// solo il flip di [useBackend] e l'uso di [backendBaseUrl].
class AppConfig {
  const AppConfig._();

  /// Se true, i dati passano dal backend; se false, chiamate dirette alle API.
  static const bool useBackend = false;

  /// Backend Cloudflare Workers (predisposto per la v2).
  static const String backendBaseUrl = 'https://livenza-api.workers.dev';

  /// API REST delle reti di monitoraggio della Protezione Civile FVG
  /// (documentazione Swagger in /api/apidocs/).
  static const String monitorBaseUrl =
      'https://monitor.protezionecivile.fvg.it/api';

  /// API del Centro Funzionale Decentrato (allerte regionali).
  static const String cfdBaseUrl = 'https://cfd.protezionecivile.fvg.it';

  /// Zona di allertamento in cui ricade Sacile (pianura occidentale).
  static const String alertZoneKey = 'fvgA';

  /// Stazione idrometeo "Sacile" sulla rete di monitoraggio.
  static const int sacileStationId = 543;

  /// Sensore idrometro (codice IDRO, valori in metri, cadenza 15 min).
  static const int sacileHydroSensorId = 24;

  /// Finestra di storico mostrata nel grafico.
  static const Duration historyWindow = Duration(hours: 48);

  /// Soglie di allerta per il Livenza a Sacile (metri sull'idrometro).
  static const double sogliaGialla = 5.5;
  static const double sogliaRossa = 6.0;

  /// Coordinate di Sacile per le previsioni meteo.
  static const double sacileLat = 45.9509;
  static const double sacileLon = 12.5022;

  /// Stazioni XML ARPA-OSMER (al momento non usato: Open-Meteo
  /// copre le previsioni, l'API monitor i dati idrometrici).
  static const String osmerBaseUrl = 'https://dev.meteo.fvg.it/xml/stazioni';

  /// Bollettini di previsione ARPA-OSMER (file `PW<yyyyMMdd>.xml`).
  static const String osmerForecastUrl =
      'https://dev.meteo.fvg.it/xml/previsioni';

  /// Zona del bollettino OSMER in cui ricade Sacile.
  static const String osmerZone = 'Z2'; // Alta Pianura

  /// Tile raster della mappa: CARTO Voyager (gratuito per uso non
  /// commerciale, attribuzione OSM + CARTO richiesta). Non si usa
  /// tile.openstreetmap.org: la Tile Usage Policy OSMF ne vieta
  /// l'uso nelle app distribuite.
  static const String mapTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const List<String> mapTileSubdomains = ['a', 'b', 'c', 'd'];

  /// API previsioni meteo Open-Meteo.
  static const String openMeteoBaseUrl =
      'https://api.open-meteo.com/v1/forecast';

  /// API storico Open-Meteo (rianalisi ERA5, dal 1940).
  static const String openMeteoArchiveUrl =
      'https://archive-api.open-meteo.com/v1/archive';

  /// API ensemble Open-Meteo: più scenari dello stesso modello,
  /// usati per stimare l'affidabilità della previsione.
  static const String openMeteoEnsembleUrl =
      'https://ensemble-api.open-meteo.com/v1/ensemble';

  /// Modello ensemble (ICON seamless, ~40 membri).
  static const String ensembleModel = 'icon_seamless';

  /// Primo anno disponibile nella rianalisi ERA5.
  static const int historyStartYear = 1940;

  /// Periodo climatico di riferimento per i confronti (pioggia).
  static const int climatologyStartYear = 1991;
  static const int climatologyEndYear = 2020;

  /// Baseline "pre-riscaldamento" (standard WMO) per le anomalie
  /// di temperatura.
  static const int baselineStartYear = 1961;
  static const int baselineEndYear = 1990;

  /// Soglia dei giorni "molto caldi" (massima giornaliera, °C).
  static const double hotDayThreshold = 30.0;

  /// Età massima dello storico in cache prima di riscaricarlo.
  static const Duration historyMaxAge = Duration(days: 7);

  /// Intervallo di refresh automatico dei dati.
  static const Duration refreshInterval = Duration(minutes: 5);

  /// Età massima oltre la quale la cache è considerata "stantia".
  static const Duration cacheMaxAge = Duration(minutes: 10);

  /// Timeout per le richieste HTTP.
  static const Duration httpTimeout = Duration(seconds: 15);

  static const String appName = 'Livenza Monitor';
  static const String appTagline = 'Livelli del fiume Livenza a Sacile';
}
