import 'package:flutter/material.dart';

/// Temi chiaro e scuro dell'app, basati su [ColorScheme.fromSeed]
/// con un seed blu acqua coerente con il tema fluviale.
class AppTheme {
  const AppTheme._();

  /// Seed per il tema chiaro (blu acqua intenso).
  static const Color _seedLight = Color(0xFF0277BD);

  /// Seed per il tema scuro (azzurro più luminoso).
  static const Color _seedDark = Color(0xFF4FC3F7);

  static ThemeData light() => _build(_seedLight, Brightness.light);

  static ThemeData dark() => _build(_seedDark, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
    );
  }
}
