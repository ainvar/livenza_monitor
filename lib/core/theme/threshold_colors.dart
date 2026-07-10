import 'package:flutter/material.dart';

/// Colori delle soglie idrometriche secondo la convenzione della
/// Protezione Civile italiana (verde → giallo → arancione → rosso).
class ThresholdColors {
  const ThresholdColors._();

  /// Livello normale, nessuna criticità.
  static const Color normal = Color(0xFF2E7D32);

  /// Soglia 1 — criticità ordinaria (gialla).
  static const Color soglia1 = Color(0xFFF9A825);

  /// Soglia 2 — criticità moderata (arancione).
  static const Color soglia2 = Color(0xFFEF6C00);

  /// Soglia 3 — criticità elevata (rossa).
  static const Color soglia3 = Color(0xFFC62828);

  /// Dato non disponibile o non interpretabile.
  static const Color unknown = Color(0xFF757575);
}
