import 'basin_station.dart';

/// Ultima lettura di una stazione del bacino.
class BasinReading {
  const BasinReading({
    required this.station,
    required this.value,
    required this.timestampUtc,
  });

  final BasinStation station;

  /// Livello in metri (riferito allo zero idrometrico della stazione).
  final double value;

  final DateTime timestampUtc;

  DateTime get timestampLocal => timestampUtc.toLocal();

  Map<String, dynamic> toCacheJson() => {
    'id': station.id,
    'v': value,
    't': timestampUtc.toIso8601String(),
  };

  static BasinReading? fromCacheJson(Map<String, dynamic> json) {
    final id = json['id'];
    final v = json['v'];
    final t = json['t'];
    if (id is! int || v is! num || t is! String) return null;
    final parsed = DateTime.tryParse(t);
    if (parsed == null) return null;
    BasinStation? station;
    for (final s in basinStations) {
      if (s.id == id) {
        station = s;
        break;
      }
    }
    if (station == null) return null;
    return BasinReading(
      station: station,
      value: v.toDouble(),
      timestampUtc: parsed.toUtc(),
    );
  }
}

/// Insieme delle letture del bacino scaricate in un momento dato.
class BasinData {
  const BasinData({required this.readings, required this.fetchedAtUtc});

  /// Letture nell'ordine di [basinStations] (da monte a valle).
  final List<BasinReading> readings;

  final DateTime fetchedAtUtc;

  bool get isEmpty => readings.isEmpty;

  /// Misura più recente tra tutte le stazioni.
  DateTime? get newestMeasureUtc {
    DateTime? newest;
    for (final r in readings) {
      if (newest == null || r.timestampUtc.isAfter(newest)) {
        newest = r.timestampUtc;
      }
    }
    return newest;
  }

  Map<String, dynamic> toCacheJson() => {
    'fetchedAt': fetchedAtUtc.toIso8601String(),
    'readings': [for (final r in readings) r.toCacheJson()],
  };

  static BasinData? fromCacheJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'];
    final readings = json['readings'];
    if (fetchedAt is! String || readings is! List) return null;
    final parsed = DateTime.tryParse(fetchedAt);
    if (parsed == null) return null;
    return BasinData(
      readings: [
        for (final r in readings)
          if (r is Map<String, dynamic>) ?BasinReading.fromCacheJson(r),
      ],
      fetchedAtUtc: parsed.toUtc(),
    );
  }
}
