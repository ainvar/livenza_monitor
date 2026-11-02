import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/domain/content/flood_events.dart';

void main() {
  test('gli eventi hanno intervalli validi in ordine cronologico inverso', () {
    for (var i = 0; i < floodEvents.length; i++) {
      final event = floodEvents[i];
      expect(event.endDate.isBefore(event.startDate), isFalse);
      expect(event.startDate.month, event.month);
      expect(event.startDate.day, event.day);
      if (i > 0) {
        expect(floodEvents[i - 1].startDate.isAfter(event.startDate), isTrue);
      }
    }
  });

  test('Accadde oggi comprende tutto il periodo e il cambio di mese', () {
    final event = floodEvents.singleWhere((event) => event.year == 2010);
    expect(event.isAnniversaryOn(DateTime(2026, 10, 31)), isTrue);
    expect(event.isAnniversaryOn(DateTime(2026, 11, 1)), isTrue);
    expect(event.isAnniversaryOn(DateTime(2026, 11, 2)), isTrue);
    expect(event.isAnniversaryOn(DateTime(2026, 10, 30)), isFalse);
    expect(event.isAnniversaryOn(DateTime(2026, 11, 3)), isFalse);
    expect(event.isAnniversaryOn(DateTime(2010, 11, 1)), isFalse);
  });

  test('il racconto condiviso mantiene il contesto della pioggia', () {
    final event = floodEvents.first;
    expect(event.shareText, contains(event.dateLabel));
    expect(event.shareText, contains(event.title));
    expect(event.shareText, contains(event.story));
    expect(event.shareText, contains('non misure di stazione'));
  });
}
