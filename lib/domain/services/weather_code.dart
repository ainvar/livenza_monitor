import 'package:flutter/material.dart';

/// Descrizione (icona + testo) dei codici meteo WMO usati da Open-Meteo.
class WeatherCodeUi {
  const WeatherCodeUi._(this.icon, this.label);

  final IconData icon;
  final String label;

  static WeatherCodeUi describe(int code) => switch (code) {
        0 => const WeatherCodeUi._(Icons.wb_sunny, 'Sereno'),
        1 => const WeatherCodeUi._(Icons.wb_sunny, 'Prevalentemente sereno'),
        2 => const WeatherCodeUi._(Icons.wb_cloudy, 'Parzialmente nuvoloso'),
        3 => const WeatherCodeUi._(Icons.cloud, 'Coperto'),
        45 || 48 => const WeatherCodeUi._(Icons.dehaze, 'Nebbia'),
        >= 51 && <= 57 => const WeatherCodeUi._(Icons.grain, 'Pioviggine'),
        >= 61 && <= 67 => const WeatherCodeUi._(Icons.water_drop, 'Pioggia'),
        >= 71 && <= 77 => const WeatherCodeUi._(Icons.ac_unit, 'Neve'),
        >= 80 && <= 82 =>
          const WeatherCodeUi._(Icons.water_drop, 'Rovesci di pioggia'),
        85 || 86 => const WeatherCodeUi._(Icons.ac_unit, 'Rovesci di neve'),
        95 => const WeatherCodeUi._(Icons.thunderstorm, 'Temporale'),
        96 || 99 =>
          const WeatherCodeUi._(Icons.thunderstorm, 'Temporale con grandine'),
        _ => const WeatherCodeUi._(Icons.help_outline, 'Non disponibile'),
      };
}
