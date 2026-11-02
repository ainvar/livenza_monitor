import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:livenza_monitor/presentation/screens/news/news_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  // Lunedì 2 novembre 2026, 11:26.
  final now = DateTime(2026, 11, 2, 11, 26);

  test('meno di un minuto: adesso', () {
    expect(
      relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
      'adesso',
    );
  });

  test('minuti e ore', () {
    expect(
      relativeTime(now.subtract(const Duration(minutes: 12)), now: now),
      '12 min fa',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3 h fa',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 23)), now: now),
      '23 h fa',
    );
  });

  test('tra 24 e 48 ore: ieri con orario', () {
    expect(relativeTime(DateTime(2026, 11, 1, 7, 26), now: now), 'ieri 07:26');
  });

  test('entro la settimana: giorno della settimana', () {
    expect(relativeTime(DateTime(2026, 10, 30, 18, 0), now: now), 'ven 18:00');
  });

  test('oltre la settimana: data completa', () {
    expect(relativeTime(DateTime(2026, 10, 20, 9, 5), now: now), '20/10 09:05');
  });
}
