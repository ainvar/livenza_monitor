// Renderer headless delle schermate: disegna l'app con dati finti
// realistici e font reali, salvando un PNG per ogni vista.
//
// Non è un test dell'app: usa flutter_test per avere il motore di
// rendering senza dispositivo o finestra.
// Esecuzione:
//   flutter test tool/ui_shots.dart --dart-define=SHOTS_DIR=<cartella>
//   (opzionale: --dart-define=SHOTS_DARK=true per il tema scuro)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livenza_monitor/app.dart';

import '../test/support/fake_sources.dart';

const _shotsDir = String.fromEnvironment(
  'SHOTS_DIR',
  defaultValue: 'build/ui_shots',
);
const _dark = bool.fromEnvironment('SHOTS_DARK');

/// Dimensione logica di un telefono comune; i PNG escono a 2x.
const _logicalSize = Size(412, 915);
const _pixelRatio = 2.0;

final _boundaryKey = GlobalKey();

void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('render delle schermate', (tester) async {
    await tester.runAsync(_loadRealFonts);
    tester.view.physicalSize = _logicalSize * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    tester.platformDispatcher.platformBrightnessTestValue = _dark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    Directory(_shotsDir).createSync(recursive: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: richOverrides(),
        child: RepaintBoundary(
          key: _boundaryKey,
          child: const LivenzaMonitorApp(),
        ),
      ),
    );
    await _settle(tester);

    final suffix = _dark ? '_dark' : '';
    final shots = <String, Future<void> Function()>{
      'home_1$suffix': () async {},
      'home_2$suffix': () => _scroll(tester, -700),
      'home_3$suffix': () => _scroll(tester, -700),
      'bacino_1$suffix': () => _tab(tester, 'Bacino'),
      'bacino_2$suffix': () => _scroll(tester, -700),
      'meteo_1$suffix': () => _tab(tester, 'Meteo'),
      'meteo_2$suffix': () => _scroll(tester, -700),
      'meteo_3$suffix': () => _scroll(tester, -700),
      'meteo_4$suffix': () => _scroll(tester, -700),
      'meteo_5$suffix': () => _scroll(tester, -700),
      'scenari$suffix': () async {
        await _scrollToTop(tester);
        await _openByText(tester, 'Esplora gli scenari possibili');
      },
      'storico_1$suffix': () async {
        await _back(tester);
        await _openByText(tester, 'Pioggia dal 1940');
      },
      'storico_2$suffix': () => _scroll(tester, -700),
      'clima_1$suffix': () async {
        await _back(tester);
        await _openByText(tester, 'Temperature dal 1940');
      },
      'clima_2$suffix': () => _scroll(tester, -700),
      'notizie$suffix': () async {
        await _back(tester);
        await _tab(tester, 'Notizie');
      },
      'info_1$suffix': () => _tab(tester, 'Info'),
      'info_2$suffix': () => _scroll(tester, -700),
      'amarcord$suffix': () async {
        await _tab(tester, 'Livenza');
        await _scrollToTop(tester);
        await _openByText(tester, 'Le grandi piene del Livenza');
      },
    };

    for (final entry in shots.entries) {
      try {
        await entry.value();
        await _settle(tester);
        await _capture(tester, entry.key);
        // ignore: avoid_print
        print('OK  ${entry.key}');
      } catch (e) {
        // ignore: avoid_print
        print('ERR ${entry.key}: $e');
      }
    }
  });
}

/// Font reali dall'SDK: nei test altrimenti il testo è reso con
/// rettangoli (font "Ahem") e le icone non compaiono.
Future<void> _loadRealFonts() async {
  final root = _flutterRoot();
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) {
    throw StateError('Cartella font non trovata: ${dir.path}');
  }
  Future<ByteData> read(String name) async {
    final bytes = await File('${dir.path}/$name').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final roboto = FontLoader('Roboto')
    ..addFont(read('roboto-regular.ttf'))
    ..addFont(read('roboto-medium.ttf'))
    ..addFont(read('roboto-bold.ttf'))
    ..addFont(read('roboto-light.ttf'))
    ..addFont(read('roboto-italic.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await Future.wait([roboto.load(), icons.load()]);
}

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // .../flutter/bin/cache/dart-sdk/bin/dart.exe → .../flutter
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 4; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

/// Qualche frame a intervalli fissi: pumpAndSettle non termina con
/// gli indicatori di caricamento animati.
Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotsDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await _settle(tester, 12);
}

/// Scorre la lista principale della schermata corrente.
Future<void> _scroll(WidgetTester tester, double dy) async {
  final lists = find.byType(Scrollable).hitTestable();
  await tester.drag(lists.first, Offset(0, dy), warnIfMissed: false);
  await _settle(tester, 6);
}

Future<void> _scrollToTop(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await _scroll(tester, 2000);
  }
}

Future<void> _openByText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  // Le schermate hanno più Scrollable (liste orizzontali): si scorre
  // esplicitamente quella principale.
  await tester.scrollUntilVisible(
    finder,
    200,
    maxScrolls: 30,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.ensureVisible(finder);
  await _settle(tester, 2);
  await tester.tap(finder, warnIfMissed: false);
  await _settle(tester, 12);
}

Future<void> _back(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navigator.canPop()) navigator.pop();
  await _settle(tester, 8);
}
