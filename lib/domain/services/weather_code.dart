import 'package:flutter/material.dart';

/// Descrizione (icona, testo e colore) dei codici meteo WMO usati da
/// Open-Meteo. Di notte il sereno e il poco nuvoloso usano la luna.
class WeatherCodeUi {
  const WeatherCodeUi._(this.icon, this.label, this.color);

  final IconData icon;
  final String label;

  /// Colore d'accento della condizione (sole ambra, pioggia blu, ...).
  final Color color;

  static const _sun = Color(0xFFF9A825);
  static const _moon = Color(0xFF5C6BC0);
  static const _cloud = Color(0xFF78909C);
  static const _fog = Color(0xFF90A4AE);
  static const _rain = Color(0xFF1E88E5);
  static const _snow = Color(0xFF4FC3F7);
  static const _storm = Color(0xFF5E35B1);

  static WeatherCodeUi describe(
    int code, {
    bool isDay = true,
  }) => switch (code) {
    0 =>
      isDay
          ? const WeatherCodeUi._(Icons.wb_sunny, 'Sereno', _sun)
          : const WeatherCodeUi._(Icons.nights_stay, 'Sereno', _moon),
    1 =>
      isDay
          ? const WeatherCodeUi._(
              Icons.wb_sunny_outlined,
              'Prevalentemente sereno',
              _sun,
            )
          : const WeatherCodeUi._(
              Icons.nights_stay_outlined,
              'Prevalentemente sereno',
              _moon,
            ),
    2 => const WeatherCodeUi._(
      Icons.wb_cloudy_outlined,
      'Parzialmente nuvoloso',
      _cloud,
    ),
    3 => const WeatherCodeUi._(Icons.cloud, 'Coperto', _cloud),
    45 || 48 => const WeatherCodeUi._(Icons.dehaze, 'Nebbia', _fog),
    >= 51 && <= 57 => const WeatherCodeUi._(Icons.grain, 'Pioviggine', _rain),
    >= 61 && <= 67 => const WeatherCodeUi._(Icons.water_drop, 'Pioggia', _rain),
    >= 71 && <= 77 => const WeatherCodeUi._(Icons.ac_unit, 'Neve', _snow),
    >= 80 && <= 82 => const WeatherCodeUi._(
      Icons.umbrella,
      'Rovesci di pioggia',
      _rain,
    ),
    85 || 86 => const WeatherCodeUi._(Icons.ac_unit, 'Rovesci di neve', _snow),
    95 => const WeatherCodeUi._(Icons.thunderstorm, 'Temporale', _storm),
    96 || 99 => const WeatherCodeUi._(
      Icons.thunderstorm,
      'Temporale con grandine',
      _storm,
    ),
    _ => const WeatherCodeUi._(Icons.help_outline, 'Non disponibile', _cloud),
  };
}
