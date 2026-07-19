/// Modelli delle previsioni meteo (Open-Meteo).
///
/// Gli orari sono "naive" nel fuso Europe/Rome, come richiesti all'API:
/// vanno confrontati tra loro (es. con [WeatherCurrent.time]) e non
/// con orari UTC.
library;

/// Condizioni attuali.
class WeatherCurrent {
  const WeatherCurrent({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
  });

  final DateTime time;
  final double temperature;
  final int humidity;
  final int weatherCode;
  final double windSpeed;

  static WeatherCurrent? fromJson(Map<String, dynamic> json) {
    final time = json['time'];
    final temperature = json['temperature_2m'];
    final humidity = json['relative_humidity_2m'];
    final code = json['weather_code'];
    final wind = json['wind_speed_10m'];
    if (time is! String ||
        temperature is! num ||
        humidity is! num ||
        code is! num ||
        wind is! num) {
      return null;
    }
    final parsed = DateTime.tryParse(time);
    if (parsed == null) return null;
    return WeatherCurrent(
      time: parsed,
      temperature: temperature.toDouble(),
      humidity: humidity.round(),
      weatherCode: code.round(),
      windSpeed: wind.toDouble(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'time': time.toIso8601String(),
        'temperature_2m': temperature,
        'relative_humidity_2m': humidity,
        'weather_code': weatherCode,
        'wind_speed_10m': windSpeed,
      };
}

/// Precipitazione oraria (mm nell'ora che termina a [time]).
class HourlyPrecipitation {
  const HourlyPrecipitation({required this.time, required this.millimeters});

  final DateTime time;
  final double millimeters;
}

/// Temperatura oraria (°C a [time]).
class HourlyTemperature {
  const HourlyTemperature({required this.time, required this.celsius});

  final DateTime time;
  final double celsius;
}

/// Previsione giornaliera.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.temperatureMin,
    required this.temperatureMax,
    required this.precipitationSum,
    required this.precipitationProbability,
  });

  final DateTime date;
  final int weatherCode;
  final double temperatureMin;
  final double temperatureMax;
  final double precipitationSum;

  /// Probabilità massima di precipitazione (%), se disponibile.
  final int? precipitationProbability;
}

/// Insieme dei dati meteo scaricati.
class WeatherData {
  const WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAtUtc,
    this.hourlyTemperature = const [],
    this.dailyReliability = const {},
    this.reliability48h,
  });

  final WeatherCurrent current;

  /// Precipitazioni orarie, passato incluso (past_days).
  final List<HourlyPrecipitation> hourly;

  /// Temperature orarie, passato incluso.
  final List<HourlyTemperature> hourlyTemperature;

  final List<DailyForecast> daily;

  final DateTime fetchedAtUtc;

  /// Affidabilità (%) della previsione per giorno di calendario:
  /// concordanza tra gli scenari dell'ensemble. Vuota se non disponibile.
  final Map<DateTime, int> dailyReliability;

  /// Affidabilità (%) sulla finestra delle prossime 48 ore.
  final int? reliability48h;

  /// Copia con l'affidabilità calcolata dall'ensemble.
  WeatherData withReliability({
    required Map<DateTime, int> daily,
    required int? next48h,
  }) {
    return WeatherData(
      current: current,
      hourly: hourly,
      daily: this.daily,
      fetchedAtUtc: fetchedAtUtc,
      hourlyTemperature: hourlyTemperature,
      dailyReliability: daily,
      reliability48h: next48h,
    );
  }

  /// Parsa la risposta dell'API Open-Meteo (o la cache, stesso formato).
  static WeatherData? fromApiJson(
    Map<String, dynamic> json, {
    required DateTime fetchedAtUtc,
  }) {
    final rawCurrent = json['current'];
    if (rawCurrent is! Map<String, dynamic>) return null;
    final current = WeatherCurrent.fromJson(rawCurrent);
    if (current == null) return null;

    return WeatherData(
      current: current,
      hourly: _parseHourly(json['hourly']),
      daily: _parseDaily(json['daily']),
      fetchedAtUtc: fetchedAtUtc,
      // Dall'API le temperature stanno in `hourly`; nella cache in
      // `hourly_temp` (gli array orari possono avere lunghezze diverse).
      hourlyTemperature: _parseHourlyTemperature(
        json['hourly_temp'] ?? json['hourly'],
      ),
      dailyReliability: _parseReliability(json['reliability_daily']),
      reliability48h:
          json['reliability_48h'] is num ? (json['reliability_48h'] as num).round() : null,
    );
  }

  static List<HourlyTemperature> _parseHourlyTemperature(dynamic hourly) {
    if (hourly is! Map<String, dynamic>) return const [];
    final times = hourly['time'];
    final values = hourly['temperature_2m'];
    if (times is! List || values is! List) return const [];
    final length = times.length < values.length ? times.length : values.length;
    return [
      for (var i = 0; i < length; i++)
        if (times[i] is String && values[i] is num)
          if (DateTime.tryParse(times[i] as String) case final t?)
            HourlyTemperature(
              time: t,
              celsius: (values[i] as num).toDouble(),
            ),
    ];
  }

  /// Presente solo nella cache (l'API forecast non la fornisce).
  static Map<DateTime, int> _parseReliability(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const {};
    final result = <DateTime, int>{};
    for (final entry in raw.entries) {
      final date = DateTime.tryParse(entry.key);
      final value = entry.value;
      if (date != null && value is num) {
        result[DateTime(date.year, date.month, date.day)] = value.round();
      }
    }
    return result;
  }

  static List<HourlyPrecipitation> _parseHourly(dynamic hourly) {
    if (hourly is! Map<String, dynamic>) return const [];
    final times = hourly['time'];
    final values = hourly['precipitation'];
    if (times is! List || values is! List) return const [];
    final length = times.length < values.length ? times.length : values.length;
    return [
      for (var i = 0; i < length; i++)
        if (times[i] is String && values[i] is num)
          if (DateTime.tryParse(times[i] as String) case final t?)
            HourlyPrecipitation(
              time: t,
              millimeters: (values[i] as num).toDouble(),
            ),
    ];
  }

  static List<DailyForecast> _parseDaily(dynamic daily) {
    if (daily is! Map<String, dynamic>) return const [];
    final times = daily['time'];
    final codes = daily['weather_code'];
    final tMax = daily['temperature_2m_max'];
    final tMin = daily['temperature_2m_min'];
    final precip = daily['precipitation_sum'];
    final prob = daily['precipitation_probability_max'];
    if (times is! List ||
        codes is! List ||
        tMax is! List ||
        tMin is! List ||
        precip is! List) {
      return const [];
    }
    var length = times.length;
    for (final l in [codes, tMax, tMin, precip]) {
      if (l.length < length) length = l.length;
    }
    return [
      for (var i = 0; i < length; i++)
        if (times[i] is String &&
            codes[i] is num &&
            tMax[i] is num &&
            tMin[i] is num &&
            precip[i] is num)
          if (DateTime.tryParse(times[i] as String) case final d?)
            DailyForecast(
              date: d,
              weatherCode: (codes[i] as num).round(),
              temperatureMax: (tMax[i] as num).toDouble(),
              temperatureMin: (tMin[i] as num).toDouble(),
              precipitationSum: (precip[i] as num).toDouble(),
              precipitationProbability:
                  (prob is List && i < prob.length && prob[i] is num)
                      ? (prob[i] as num).round()
                      : null,
            ),
    ];
  }

  Map<String, dynamic> toCacheJson() => {
        'fetchedAt': fetchedAtUtc.toIso8601String(),
        'reliability_daily': {
          for (final e in dailyReliability.entries)
            e.key.toIso8601String(): e.value,
        },
        if (reliability48h != null) 'reliability_48h': reliability48h,
        'current': current.toCacheJson(),
        'hourly': {
          'time': [for (final h in hourly) h.time.toIso8601String()],
          'precipitation': [for (final h in hourly) h.millimeters],
        },
        'hourly_temp': {
          'time': [
            for (final h in hourlyTemperature) h.time.toIso8601String(),
          ],
          'temperature_2m': [for (final h in hourlyTemperature) h.celsius],
        },
        'daily': {
          'time': [for (final d in daily) d.date.toIso8601String()],
          'weather_code': [for (final d in daily) d.weatherCode],
          'temperature_2m_max': [for (final d in daily) d.temperatureMax],
          'temperature_2m_min': [for (final d in daily) d.temperatureMin],
          'precipitation_sum': [for (final d in daily) d.precipitationSum],
          'precipitation_probability_max': [
            for (final d in daily) d.precipitationProbability,
          ],
        },
      };

  static WeatherData? fromCacheJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'];
    if (fetchedAt is! String) return null;
    final parsed = DateTime.tryParse(fetchedAt);
    if (parsed == null) return null;
    return fromApiJson(json, fetchedAtUtc: parsed.toUtc());
  }
}
