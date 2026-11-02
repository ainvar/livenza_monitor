import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/domain/content/flood_events.dart';
import 'package:livenza_monitor/presentation/screens/home/amarcord_screen.dart';

void main() {
  testWidgets('i racconti si espandono senza overflow su schermo stretto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AmarcordScreen()));
    expect(find.text(floodEvents.first.story), findsOneWidget);
    expect(find.text('Condividi il racconto'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final event = floodEvents[1];
    await tester.scrollUntilVisible(find.text(event.title), 180);
    // scrollUntilVisible si ferma appena un pixel è visibile: il centro
    // del titolo può restare fuori dal viewport e il tap mancare.
    await tester.ensureVisible(find.text(event.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(event.title));
    await tester.pumpAndSettle();
    expect(find.text(event.story), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
