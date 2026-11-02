import 'basin_station.dart';

/// Punti di previsione nel bacino; sono coordinate, non pluviometri.
class WeatherLocation {
  const WeatherLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  static const sacile = WeatherLocation(
    id: 543,
    name: 'Sacile',
    lat: 45.9509,
    lon: 12.5022,
  );

  final int id;
  final String name;
  final double lat;
  final double lon;
}

/// Scelta limitata: ogni punto viene scaricato solo quando selezionato.
final weatherLocations = <WeatherLocation>[
  WeatherLocation.sacile,
  for (final id in [587, 121, 132, 188])
    for (final station in basinStations)
      if (station.id == id)
        WeatherLocation(
          id: station.id,
          name: '${station.name} · ${station.river}',
          lat: station.lat,
          lon: station.lon,
        ),
];
