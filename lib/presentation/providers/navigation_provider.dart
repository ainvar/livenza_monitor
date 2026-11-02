import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indice della tab selezionata nella barra principale.
///
/// Esposto come provider così le card di una schermata possono portare
/// l'utente a un'altra tab (es. dalla sintesi meteo in Home al Meteo).
final rootTabProvider = StateProvider<int>((ref) => 0);

/// Indici delle tab, per non spargere numeri magici.
abstract final class RootTab {
  static const int livenza = 0;
  static const int bacino = 1;
  static const int meteo = 2;
  static const int notizie = 3;
  static const int info = 4;
}
