import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/basin_station.dart';

/// Preferenze condivise fra Home, elenco e dettaglio stazione.
/// Rimangono sul dispositivo e non richiedono account o rete.
class FavoriteStationsNotifier extends AsyncNotifier<Set<int>> {
  static const storageKey = 'favorite_stations_v1';
  Future<void> _pending = Future<void>.value();

  @override
  Future<Set<int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final knownIds = basinStations.map((station) => station.id).toSet();
    return Set.unmodifiable(
      (prefs.getStringList(storageKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .where(knownIds.contains),
    );
  }

  /// Serializza i tocchi rapidi per non perdere modifiche nella persistenza.
  /// In caso di errore ripristina la selezione precedente e avvisa il chiamante.
  Future<void> toggle(int stationId) {
    if (!basinStations.any((station) => station.id == stationId)) {
      return Future<void>.error(ArgumentError.value(stationId, 'stationId'));
    }
    final operation = _pending.then((_) async {
      final previous = await future;
      final next = {...previous};
      if (!next.remove(stationId)) next.add(stationId);
      state = AsyncData(Set.unmodifiable(next));
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = await prefs.setStringList(
          storageKey,
          (next.toList()..sort()).map((id) => '$id').toList(),
        );
        if (!saved) throw StateError('Preferiti non salvati');
      } catch (_) {
        state = AsyncData(previous);
        rethrow;
      }
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

final favoriteStationsProvider =
    AsyncNotifierProvider<FavoriteStationsNotifier, Set<int>>(
      FavoriteStationsNotifier.new,
    );
