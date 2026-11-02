import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/presentation/providers/favorite_stations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ricarica solo preferiti che appartengono al bacino', () async {
    SharedPreferences.setMockInitialValues({
      FavoriteStationsNotifier.storageKey: ['58', '543', 'non valido', '99999'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(favoriteStationsProvider.future), {58, 543});
  });

  test(
    'serializza tocchi rapidi e conserva i preferiti dopo il riavvio',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(favoriteStationsProvider.future);
      final notifier = container.read(favoriteStationsProvider.notifier);
      await Future.wait([
        notifier.toggle(58),
        notifier.toggle(543),
        notifier.toggle(58),
      ]);
      expect(container.read(favoriteStationsProvider).requireValue, {543});
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      expect(await restored.read(favoriteStationsProvider.future), {543});
    },
  );

  test('una stazione sconosciuta non modifica i preferiti', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(favoriteStationsProvider.future);
    await expectLater(
      container.read(favoriteStationsProvider.notifier).toggle(-1),
      throwsArgumentError,
    );
    expect(container.read(favoriteStationsProvider).requireValue, isEmpty);
  });
}
