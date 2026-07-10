// Genera le immagini sorgente dell'icona launcher in assets/icon/.
//
// Non è un test dell'app: usa flutter_test solo per avere a disposizione
// il motore di rendering (dart:ui) senza dipendenze esterne.
// Esecuzione:  flutter test tool/generate_icons.dart
// Poi:         dart run flutter_launcher_icons

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const double _canvas = 1024;

void main() {
  test('genera icon.png e icon_foreground.png', () async {
    // Icona "classica": sfondo pieno + soggetto.
    await _writePng('assets/icon/icon.png', withBackground: true, scale: 0.86);
    // Foreground per icona adattiva: solo soggetto, dentro la safe zone.
    await _writePng(
      'assets/icon/icon_foreground.png',
      withBackground: false,
      scale: 0.60,
    );
  });
}

Future<void> _writePng(
  String path, {
  required bool withBackground,
  required double scale,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    const ui.Rect.fromLTWH(0, 0, _canvas, _canvas),
  );

  if (withBackground) {
    _drawBackground(canvas);
  }

  // Scala il soggetto attorno al centro (per la safe zone adattiva).
  const center = _canvas / 2;
  canvas
    ..translate(center, center)
    ..scale(scale)
    ..translate(-center, -center);
  _drawSubject(canvas);

  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Sfondo: gradiente verticale blu acqua.
void _drawBackground(ui.Canvas canvas) {
  final paint = ui.Paint()
    ..shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(0, _canvas),
      const [ui.Color(0xFF0288D1), ui.Color(0xFF01579B)],
    );
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _canvas, _canvas), paint);
}

/// Soggetto: asta idrometrica con tacche, parzialmente immersa in tre onde.
void _drawSubject(ui.Canvas canvas) {
  final white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);

  // Asta idrometrica verticale.
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTRB(456, 150, 528, 700),
      const ui.Radius.circular(36),
    ),
    white,
  );

  // Tacche di misura a destra dell'asta.
  for (final y in const [250.0, 360.0, 470.0]) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(528, y - 11, 96, 22),
        const ui.Radius.circular(11),
      ),
      white,
    );
  }

  // Tre onde con trasparenza decrescente in profondità.
  _drawWave(canvas, yCenter: 660, phase: 0, alpha: 1.0);
  _drawWave(canvas, yCenter: 790, phase: math.pi / 2, alpha: 0.78);
  _drawWave(canvas, yCenter: 920, phase: math.pi, alpha: 0.52);
}

void _drawWave(
  ui.Canvas canvas, {
  required double yCenter,
  required double phase,
  required double alpha,
}) {
  const amplitude = 30.0;
  const wavelength = 400.0;

  final paint = ui.Paint()
    ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: alpha)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 58
    ..strokeCap = ui.StrokeCap.round;

  final path = ui.Path();
  for (double x = -40; x <= _canvas + 40; x += 8) {
    final y =
        yCenter + amplitude * math.sin(2 * math.pi * x / wavelength + phase);
    if (x == -40) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  canvas.drawPath(path, paint);
}
