// Smoke test: l'app si avvia con dati finti e mostra livello e allerta.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livenza_monitor/app.dart';
import 'package:livenza_monitor/data/models/regional_alert.dart';
import 'package:livenza_monitor/presentation/providers/alert_providers.dart';
import 'package:livenza_monitor/presentation/providers/basin_providers.dart';
import 'package:livenza_monitor/presentation/providers/level_providers.dart';
import 'package:livenza_monitor/presentation/providers/news_providers.dart';
import 'package:livenza_monitor/presentation/providers/weather_providers.dart';

import 'support/fake_sources.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  List<RegionalAlert> alerts = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        levelDatasourceProvider.overrideWithValue(SimpleLevelDatasource()),
        basinDatasourceProvider.overrideWithValue(SimpleBasinDatasource()),
        weatherDatasourceProvider.overrideWithValue(SimpleWeatherDatasource()),
        newsDatasourceProvider.overrideWithValue(SimpleNewsDatasource()),
        cfdAlertDatasourceProvider.overrideWithValue(
          FakeAlertDatasource(alerts),
        ),
        mapTileProviderFactoryProvider.overrideWithValue(FakeTileProvider.new),
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

  testWidgets('L\'app mostra il livello e lo stato di allerta', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Livenza a Sacile'), findsOneWidget);

    // Livello, stato e trend visibili.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('sacile-latest-level')))
          .data,
      '2,81 m',
    );
    expect(find.text('Sotto le soglie indicative'), findsOneWidget);
    expect(find.text('In salita'), findsOneWidget);
    expect(find.textContaining('Aggiornato alle'), findsOneWidget);

    // La sintesi mantiene distinta la misura dalle allerte ufficiali.
    expect(find.text('Cosa sta cambiando'), findsOneWidget);
    expect(find.text('Soglia indicativa gialla superata'), findsNothing);
    expect(
      find.text('Nessuna allerta ufficiale in corso o imminente'),
      findsOneWidget,
    );

    // La NavigationBar con le 5 tab è presente.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Bacino'), findsOneWidget);
    expect(find.text('Meteo'), findsOneWidget);
    expect(find.text('Notizie'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);

    // Senza allerte del CFD la card non compare.
    expect(find.textContaining('ALLERTA'), findsNothing);
  });

  testWidgets('Con un\'allerta in corso la card compare in Home', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await _pumpApp(
      tester,
      alerts: [
        fakeAlert(
          fromUtc: now.subtract(const Duration(hours: 2)),
          toUtc: now.add(const Duration(hours: 10)),
        ),
      ],
    );

    expect(find.text('ALLERTA GIALLA — n. 21'), findsOneWidget);
    expect(find.text('Temporali · temporali localmente forti'), findsOneWidget);
    expect(find.textContaining('In corso fino alle'), findsOneWidget);
  });

  testWidgets('La Home resta leggibile su telefono con caratteri grandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un\'allerta scaduta non mostra la card', (tester) async {
    final now = DateTime.now().toUtc();
    await _pumpApp(
      tester,
      alerts: [
        fakeAlert(
          fromUtc: now.subtract(const Duration(days: 2)),
          toUtc: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    expect(find.textContaining('ALLERTA'), findsNothing);
  });

  testWidgets('La mappa del bacino mantiene attribuzione visibile e stazioni', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      find.text('© OpenStreetMap contributors').hitTestable(),
      findsOneWidget,
    );
    expect(find.byTooltip('Gorgazzo (Polcenigo) · Gorgazzo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
