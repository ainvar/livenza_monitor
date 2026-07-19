// Smoke test: l'app si avvia con dati finti e mostra livello e allerta.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livenza_monitor/app.dart';
import 'package:livenza_monitor/data/datasources/basin_datasource.dart';
import 'package:livenza_monitor/data/datasources/level_datasource.dart';
import 'package:livenza_monitor/data/models/basin_reading.dart';
import 'package:livenza_monitor/data/models/basin_station.dart';
import 'package:livenza_monitor/data/datasources/cfd_alert_datasource.dart';
import 'package:livenza_monitor/data/datasources/news_datasource.dart';
import 'package:livenza_monitor/data/datasources/weather_datasource.dart';
import 'package:livenza_monitor/data/models/hydro_measure.dart';
import 'package:livenza_monitor/data/models/news_item.dart';
import 'package:livenza_monitor/data/models/regional_alert.dart';
import 'package:livenza_monitor/data/models/weather_data.dart';
import 'package:livenza_monitor/presentation/providers/alert_providers.dart';
import 'package:livenza_monitor/presentation/providers/basin_providers.dart';
import 'package:livenza_monitor/presentation/providers/level_providers.dart';
import 'package:livenza_monitor/presentation/providers/news_providers.dart';
import 'package:livenza_monitor/presentation/providers/weather_providers.dart';

/// Datasource finto: serie in leggera salita fino a 2,81 m.
class _FakeDatasource implements LevelDatasource {
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

/// Datasource bacino finto: una lettura per ogni stazione curata.
class _FakeBasinDatasource implements BasinDatasource {
  @override
  Future<List<BasinReading>> fetchLatestReadings() async {
    final now = DateTime.now().toUtc();
    return [
      for (final s in basinStations)
        BasinReading(station: s, value: 1.5, timestampUtc: now),
    ];
  }
}

/// Datasource meteo finto.
class _FakeWeatherDatasource implements WeatherDatasource {
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
            date: DateTime(now.year, now.month, now.day)
                .add(Duration(days: i)),
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

/// Datasource notizie finto.
class _FakeNewsDatasource implements NewsDatasource {
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

/// Datasource allerte finto.
class _FakeAlertDatasource implements CfdAlertDatasource {
  _FakeAlertDatasource(this.alerts);

  final List<RegionalAlert> alerts;

  @override
  Future<List<RegionalAlert>> fetchRecentAlerts() async => alerts;
}

RegionalAlert _alert({
  required DateTime fromUtc,
  required DateTime toUtc,
  int level = 1,
}) =>
    RegionalAlert(
      number: 21,
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

/// PNG trasparente 1x1, per non scaricare tile di mappa nei test.
final _transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// TileProvider che restituisce sempre un'immagine trasparente.
class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  List<RegionalAlert> alerts = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        levelDatasourceProvider.overrideWithValue(_FakeDatasource()),
        basinDatasourceProvider.overrideWithValue(_FakeBasinDatasource()),
        weatherDatasourceProvider.overrideWithValue(_FakeWeatherDatasource()),
        newsDatasourceProvider.overrideWithValue(_FakeNewsDatasource()),
        cfdAlertDatasourceProvider
            .overrideWithValue(_FakeAlertDatasource(alerts)),
        mapTileProviderFactoryProvider
            .overrideWithValue(_FakeTileProvider.new),
      ],
      child: const LivenzaMonitorApp(),
    ),
  );
  // Lascia completare i fetch finti e la scrittura in cache.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('L\'app mostra il livello e lo stato di allerta',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('Livenza a Sacile'), findsOneWidget);

    // Livello, stato e trend visibili.
    expect(find.text('2,81 m'), findsOneWidget);
    expect(find.text('Livello normale'), findsOneWidget);
    expect(find.text('In salita'), findsOneWidget);
    expect(find.textContaining('Aggiornato alle'), findsOneWidget);

    // Le soglie sono elencate.
    expect(find.text('Allerta gialla'), findsOneWidget);
    expect(find.text('Allerta rossa'), findsOneWidget);

    // La NavigationBar con le 5 tab è presente.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Bacino'), findsOneWidget);
    expect(find.text('Meteo'), findsOneWidget);
    expect(find.text('Notizie'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);

    // Senza allerte del CFD la card non compare.
    expect(find.textContaining('ALLERTA'), findsNothing);
  });

  testWidgets('Con un\'allerta in corso la card compare in Home',
      (tester) async {
    final now = DateTime.now().toUtc();
    await _pumpApp(tester, alerts: [
      _alert(
        fromUtc: now.subtract(const Duration(hours: 2)),
        toUtc: now.add(const Duration(hours: 10)),
      ),
    ]);

    expect(find.text('ALLERTA GIALLA — n. 21'), findsOneWidget);
    expect(
      find.text('Temporali · temporali localmente forti'),
      findsOneWidget,
    );
    expect(find.textContaining('In corso fino alle'), findsOneWidget);
  });

  testWidgets('Un\'allerta scaduta non mostra la card', (tester) async {
    final now = DateTime.now().toUtc();
    await _pumpApp(tester, alerts: [
      _alert(
        fromUtc: now.subtract(const Duration(days: 2)),
        toUtc: now.subtract(const Duration(days: 1)),
      ),
    ]);

    expect(find.textContaining('ALLERTA'), findsNothing);
  });
}
