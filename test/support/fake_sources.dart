// Sorgenti dati finte condivise da test e strumenti di anteprima.
//
// Due famiglie: quelle "semplici" (valori fissi, usate dagli smoke test
// che fanno asserzioni puntuali) e quelle "ricche" (serie realistiche,
// usate per rendere le schermate in tool/ui_shots.dart).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:livenza_monitor/data/datasources/basin_datasource.dart';
import 'package:livenza_monitor/data/datasources/cfd_alert_datasource.dart';
import 'package:livenza_monitor/data/datasources/ensemble_datasource.dart';
import 'package:livenza_monitor/data/datasources/history_datasource.dart';
import 'package:livenza_monitor/data/datasources/level_datasource.dart';
import 'package:livenza_monitor/data/datasources/news_datasource.dart';
import 'package:livenza_monitor/data/datasources/osmer_datasource.dart';
import 'package:livenza_monitor/data/datasources/station_history_datasource.dart';
import 'package:livenza_monitor/data/datasources/weather_datasource.dart';
import 'package:livenza_monitor/data/models/basin_reading.dart';
import 'package:livenza_monitor/data/models/basin_station.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/data/models/news_item.dart';
import 'package:livenza_monitor/data/models/osmer_bulletin.dart';
import 'package:livenza_monitor/data/models/regional_alert.dart';
import 'package:livenza_monitor/data/models/weather_data.dart';
import 'package:livenza_monitor/presentation/providers/alert_providers.dart';
import 'package:livenza_monitor/presentation/providers/basin_providers.dart';
import 'package:livenza_monitor/presentation/providers/history_providers.dart';
import 'package:livenza_monitor/presentation/providers/level_providers.dart';
import 'package:livenza_monitor/presentation/providers/news_providers.dart';
import 'package:livenza_monitor/presentation/providers/station_history_provider.dart';
import 'package:livenza_monitor/presentation/providers/weather_providers.dart';

// ---------------------------------------------------------------------------
// Livelli
// ---------------------------------------------------------------------------

/// Serie in leggera salita fino a 2,81 m (valori attesi dagli smoke test).
class SimpleLevelDatasource implements LevelDatasource {
  @override
  Future<List<HydroMeasure>> fetchHistory({required Duration window}) async {
    final now = DateTime.now().toUtc();
    const values = [2.70, 2.72, 2.75, 2.78, 2.81];
    return [
      for (final (i, v) in values.indexed)
        HydroMeasure(
          timestampUtc: now.subtract(
            Duration(minutes: 15 * (values.length - 1 - i)),
          ),
          value: v,
        ),
    ];
  }
}

/// 48 ore di misure ogni 15 minuti con una piccola piena in corso.
class RichLevelDatasource implements LevelDatasource {
  RichLevelDatasource({this.base = 2.6, this.amplitude = 0.9});

  final double base;
  final double amplitude;

  @override
  Future<List<HydroMeasure>> fetchHistory({required Duration window}) async {
    return richLevelSeries(base: base, amplitude: amplitude);
  }
}

List<HydroMeasure> richLevelSeries({
  double base = 2.6,
  double amplitude = 0.9,
  int hours = 48,
}) {
  final now = DateTime.now().toUtc();
  final steps = hours * 4;
  return [
    for (var i = 0; i <= steps; i++)
      HydroMeasure(
        timestampUtc: now.subtract(Duration(minutes: 15 * (steps - i))),
        // Lenta salita negli ultimi due terzi, con un po' di rumore.
        value:
            base +
            amplitude * math.max(0, (i / steps - 0.35) / 0.65) +
            0.015 * math.sin(i / 3),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Bacino
// ---------------------------------------------------------------------------

/// Una lettura per ogni stazione curata, tutte a 1,5 m.
class SimpleBasinDatasource implements BasinDatasource {
  @override
  Future<List<BasinReading>> fetchLatestReadings() async {
    final now = DateTime.now().toUtc();
    return [
      for (final s in basinStations)
        BasinReading(station: s, value: 1.5, timestampUtc: now),
    ];
  }
}

/// Letture variegate; una stazione resta senza misura.
class RichBasinDatasource implements BasinDatasource {
  @override
  Future<List<BasinReading>> fetchLatestReadings() async {
    final now = DateTime.now().toUtc();
    return [
      for (final (i, s) in basinStations.indexed)
        if (i != 7)
          BasinReading(
            station: s,
            value: s.isReference ? 3.42 : 0.3 + (i * 0.37) % 2.1,
            timestampUtc: now.subtract(Duration(minutes: 15 + 5 * (i % 3))),
          ),
    ];
  }
}

/// Storico di 48 ore per qualunque stazione.
class RichStationHistoryDatasource implements StationHistoryDatasource {
  @override
  Future<List<HydroMeasure>> fetchHistory(int stationId) async {
    final station = basinStations.firstWhere((s) => s.id == stationId);
    return richLevelSeries(
      base: station.isReference ? 2.6 : 0.8,
      amplitude: station.isReference ? 0.9 : 0.4,
    );
  }
}

// ---------------------------------------------------------------------------
// Meteo
// ---------------------------------------------------------------------------

/// Dati fissi e semplici (nuvoloso, 22,5 °C).
class SimpleWeatherDatasource implements WeatherDatasource {
  @override
  Future<WeatherData> fetchForecast() async {
    final now = DateTime.now();
    return WeatherData(
      current: WeatherCurrent(
        time: now,
        temperature: 22.5,
        humidity: 60,
        weatherCode: 2,
        windSpeed: 6.0,
      ),
      hourly: [
        for (var i = -24; i <= 48; i++)
          HourlyPrecipitation(
            time: now.add(Duration(hours: i)),
            millimeters: i.isEven ? 0.0 : 0.4,
          ),
      ],
      hourlyTemperature: [
        for (var i = -24; i <= 48; i++)
          HourlyTemperature(
            time: now.add(Duration(hours: i)),
            celsius: 20.0 + (i % 12),
          ),
      ],
      daily: [
        for (var i = 0; i < 7; i++)
          DailyForecast(
            date: DateTime(now.year, now.month, now.day).add(Duration(days: i)),
            weatherCode: 3,
            temperatureMin: 15,
            temperatureMax: 25,
            precipitationSum: 1.2,
            precipitationProbability: 40,
          ),
      ],
      fetchedAtUtc: now.toUtc(),
    );
  }
}

/// Una settimana realistica: due giorni di pioggia e temporali, poi
/// miglioramento; tutti i campi (percepita, raffiche, alba/tramonto...).
class RichWeatherDatasource implements WeatherDatasource {
  @override
  Future<WeatherData> fetchForecast() async => richWeatherData();
}

WeatherData richWeatherData() {
  final now = DateTime.now();
  final nowHour = DateTime(now.year, now.month, now.day, now.hour);
  final today = DateTime(now.year, now.month, now.day);

  // Giorno relativo -1..7: profilo di pioggia della settimana.
  double rainOf(int dayOffset, int hour) {
    final mm = switch (dayOffset) {
      0 => hour >= 15 && hour <= 20 ? 1.8 + 2.2 * math.sin(hour - 15) : 0.0,
      1 => hour >= 3 && hour <= 14 ? 3.5 + 4.5 * math.sin(hour / 2) : 0.1,
      2 => hour >= 10 && hour <= 13 ? 0.6 : 0.0,
      _ => 0.0,
    };
    return math.max(0.0, mm);
  }

  int codeOf(int dayOffset, int hour, double mm) {
    if (mm >= 4) return 95;
    if (mm >= 1.5) return 61;
    if (mm > 0) return 80;
    if (dayOffset == 1) return 3;
    if (dayOffset == 2) return 2;
    return hour >= 7 && hour <= 17 ? (dayOffset.isEven ? 0 : 1) : 0;
  }

  final hourly = <HourlyPrecipitation>[];
  final temps = <HourlyTemperature>[];
  final detail = <HourlyForecast>[];
  for (var i = -24; i <= 168; i++) {
    final t = nowHour.add(Duration(hours: i));
    final dayOffset = DateTime(t.year, t.month, t.day).difference(today).inDays;
    final mm = rainOf(dayOffset, t.hour);
    final code = codeOf(dayOffset, t.hour, mm);
    final isDay = t.hour >= 7 && t.hour < 18;
    final temp =
        11 +
        5.5 * math.sin((t.hour - 9) / 24 * 2 * math.pi) -
        (dayOffset == 1 ? 3 : 0) +
        dayOffset * 0.3;
    hourly.add(HourlyPrecipitation(time: t, millimeters: mm));
    temps.add(HourlyTemperature(time: t, celsius: temp));
    detail.add(
      HourlyForecast(
        time: t,
        weatherCode: code,
        precipitationProbability: mm > 0 ? (55 + mm * 8).clamp(0, 95).round() : 8,
        windSpeed: 6 + 4 * math.sin(i / 7) + (mm > 3 ? 12 : 0),
        isDay: isDay,
      ),
    );
  }

  final daily = <DailyForecast>[];
  for (var d = 0; d < 7; d++) {
    final date = today.add(Duration(days: d));
    var sum = 0.0;
    var hours = 0.0;
    var maxCode = 0;
    for (var h = 0; h < 24; h++) {
      final mm = rainOf(d, h);
      sum += mm;
      if (mm > 0) hours++;
      final c = codeOf(d, h, mm);
      if (c > maxCode) maxCode = c;
    }
    daily.add(
      DailyForecast(
        date: date,
        weatherCode: maxCode,
        temperatureMin: 6 + d * 0.4 - (d == 1 ? 2 : 0),
        temperatureMax: 15 + d * 0.5 - (d == 1 ? 4 : 0),
        precipitationSum: sum,
        precipitationProbability: sum > 0 ? (40 + sum * 2).clamp(0, 95).round() : 10,
        sunrise: date.add(const Duration(hours: 6, minutes: 52)),
        sunset: date.add(const Duration(hours: 16, minutes: 55)),
        windSpeedMax: 12 + d * 2.0 + (d == 1 ? 14 : 0),
        windGustsMax: 28 + d * 3.0 + (d == 1 ? 24 : 0),
        precipitationHours: hours,
        uvIndexMax: d == 1 ? 1.2 : 2.6,
      ),
    );
  }

  return WeatherData(
    current: WeatherCurrent(
      time: now,
      temperature: 13.7,
      humidity: 71,
      weatherCode: 2,
      windSpeed: 9.4,
      apparentTemperature: 11.9,
      isDay: now.hour >= 7 && now.hour < 18,
      windDirection: 63,
      windGusts: 21.2,
    ),
    hourly: hourly,
    hourlyTemperature: temps,
    hourlyForecast: detail,
    daily: daily,
    fetchedAtUtc: now.toUtc(),
  );
}

/// 40 membri con dispersione crescente nel tempo.
class RichEnsembleDatasource implements EnsembleDatasource {
  @override
  Future<EnsembleHourly> fetchHourlyPrecipitation() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final times = [for (var h = 0; h < 168; h++) start.add(Duration(hours: h))];
    final rnd = math.Random(7);
    final members = <List<double?>>[];
    for (var m = 0; m < 40; m++) {
      final shift = rnd.nextDouble() * 10 - 5;
      final scale = 0.5 + rnd.nextDouble();
      members.add([
        for (var h = 0; h < 168; h++)
          () {
            final hour = h + shift;
            final event1 = hour >= 20 && hour <= 40 ? 2.0 * scale : 0.0;
            final event2 = hour >= 100 && hour <= 120 && m % 3 != 0
                ? 3.0 * scale
                : 0.0;
            return (event1 + event2) * (0.6 + rnd.nextDouble() * 0.8);
          }(),
      ]);
    }
    return EnsembleHourly(times: times, members: members);
  }
}

/// Bollettino OSMER con situazione, domani e dopodomani.
class RichOsmerDatasource implements OsmerDatasource {
  @override
  Future<OsmerBulletin> fetchBulletin() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return OsmerBulletin(
      issuedUtc: now.toUtc().subtract(const Duration(hours: 3)),
      situazione:
          'Una depressione in avvicinamento dalla Francia favorirà '
          'l\'afflusso di correnti umide e instabili da sud-ovest; la '
          'fase più perturbata è attesa tra la notte e la mattinata di '
          'domani, con precipitazioni anche abbondanti sulle Prealpi.',
      days: [
        OsmerDay(
          date: today.add(const Duration(days: 1)),
          label: 'DOMANI',
          text:
              'Cielo coperto con piogge diffuse, anche a carattere di '
              'rovescio o temporale, più intense al mattino. Quota neve '
              'oltre i 1800 m. Vento di scirocco moderato sulla costa.',
          attendibilita: 80,
        ),
        OsmerDay(
          date: today.add(const Duration(days: 2)),
          label: 'DOPODOMANI',
          text:
              'Residua variabilità al mattino con qualche rovescio sulla '
              'zona montana, poi graduale miglioramento da ovest. '
              'Temperature in calo.',
          attendibilita: 60,
        ),
      ],
    );
  }
}

/// Serie 1940→oggi con stagionalità e lieve riscaldamento.
class RichHistoryDatasource implements HistoryDatasource {
  @override
  Future<List<RawDailyWeather>> fetchDailySeries() async {
    final now = DateTime.now();
    final rnd = math.Random(1940);
    final result = <RawDailyWeather>[];
    for (var year = 1940; year <= now.year; year++) {
      for (var i = 0;; i++) {
        final d = DateTime(year, 1, 1 + i);
        if (d.year != year) break;
        if (d.isAfter(now.subtract(const Duration(days: 5)))) break;
        final season = math.sin((i - 100) / 365 * 2 * math.pi);
        final warming = (year - 1940) * 0.022;
        final tMean = 12.5 + 9.5 * season + warming + rnd.nextDouble() * 3 - 1.5;
        final rain = rnd.nextDouble() < 0.3
            ? math.pow(rnd.nextDouble(), 2.2) * 42 * (year == 1966 && i > 300 && i < 310 ? 4 : 1)
            : 0.0;
        result.add((
          date: d,
          precipitation: rain.toDouble(),
          tMean: tMean,
          tMax: tMean + 5 + rnd.nextDouble() * 2,
        ));
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Notizie e allerte
// ---------------------------------------------------------------------------

class SimpleNewsDatasource implements NewsDatasource {
  @override
  Future<List<NewsItem>> fetchAll() async => [
    NewsItem(
      title: 'Livenza sorvegliato speciale a Sacile',
      link: 'https://esempio.it/livenza',
      source: 'Test',
      publishedUtc: DateTime.now().toUtc(),
    ),
  ];
}

class RichNewsDatasource implements NewsDatasource {
  @override
  Future<List<NewsItem>> fetchAll() async {
    final now = DateTime.now().toUtc();
    return [
      NewsItem(
        title:
            'Maltempo, il Livenza sale a Sacile: attivato il monitoraggio '
            'degli argini in zona Cavolano',
        link: 'https://esempio.it/1',
        source: 'Il Friuli',
        publishedUtc: now.subtract(const Duration(hours: 2)),
      ),
      NewsItem(
        title:
            'Caneva, frana sulla strada per il Cansiglio dopo le piogge '
            'della notte',
        link: 'https://esempio.it/2',
        source: 'Nordest24',
        publishedUtc: now.subtract(const Duration(hours: 9)),
      ),
      NewsItem(
        title: 'Polcenigo, il Gorgazzo torna a scorrere impetuoso',
        link: 'https://esempio.it/3',
        source: 'Il Popolo',
        publishedUtc: now.subtract(const Duration(days: 1, hours: 4)),
      ),
    ];
  }
}

class FakeAlertDatasource implements CfdAlertDatasource {
  FakeAlertDatasource(this.alerts);

  final List<RegionalAlert> alerts;

  @override
  Future<List<RegionalAlert>> fetchRecentAlerts() async => alerts;
}

RegionalAlert fakeAlert({
  required DateTime fromUtc,
  required DateTime toUtc,
  int level = 1,
  int number = 21,
}) => RegionalAlert(
  number: number,
  emittedUtc: fromUtc.subtract(const Duration(hours: 12)),
  fromUtc: fromUtc,
  toUtc: toUtc,
  level: level,
  phenomena: const ['temporali', 'temporali localmente forti'],
  situation: 'Correnti instabili.',
  forecast: 'Temporali sparsi.',
  assessment: 'Possibili criticità locali.',
  operationalStage: 'ATTENZIONE',
  documentUrl: 'https://esempio.it/allerta.pdf',
);

// ---------------------------------------------------------------------------
// Mappa
// ---------------------------------------------------------------------------

/// PNG trasparente 1x1, per non scaricare tile di mappa nei test.
final transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// TileProvider che restituisce sempre un'immagine trasparente.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(transparentPng);
  }
}

// ---------------------------------------------------------------------------
// Override pronti
// ---------------------------------------------------------------------------

/// Override "ricchi" per rendere tutte le schermate con dati realistici.
List<Override> richOverrides({bool withAlert = true}) {
  final nowUtc = DateTime.now().toUtc();
  return [
    levelDatasourceProvider.overrideWithValue(RichLevelDatasource()),
    basinDatasourceProvider.overrideWithValue(RichBasinDatasource()),
    stationHistoryDatasourceProvider.overrideWithValue(
      RichStationHistoryDatasource(),
    ),
    weatherDatasourceProvider.overrideWithValue(RichWeatherDatasource()),
    ensembleDatasourceProvider.overrideWithValue(RichEnsembleDatasource()),
    osmerDatasourceProvider.overrideWithValue(RichOsmerDatasource()),
    historyDatasourceProvider.overrideWithValue(RichHistoryDatasource()),
    newsDatasourceProvider.overrideWithValue(RichNewsDatasource()),
    cfdAlertDatasourceProvider.overrideWithValue(
      FakeAlertDatasource([
        if (withAlert)
          fakeAlert(
            fromUtc: nowUtc.subtract(const Duration(hours: 3)),
            toUtc: nowUtc.add(const Duration(hours: 18)),
          ),
      ]),
    ),
    mapTileProviderFactoryProvider.overrideWithValue(FakeTileProvider.new),
  ];
}
