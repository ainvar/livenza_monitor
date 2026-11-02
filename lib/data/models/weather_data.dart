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
    this.apparentTemperature,
    this.isDay = true,
    this.windDirection,
    this.windGusts,
  });

  final DateTime time;
  final double temperature;
  final int humidity;
  final int weatherCode;
  final double windSpeed;

  /// Temperatura percepita (°C), se disponibile.
  final double? apparentTemperature;

  /// Giorno (true) o notte (false): sceglie l'icona.
  final bool isDay;

  /// Direzione di provenienza del vento in gradi (0 = nord).
  final int? windDirection;

  /// Raffiche (km/h), se disponibili.
  final double? windGusts;

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
    final apparent = json['apparent_temperature'];
    final isDay = json['is_day'];
    final direction = json['wind_direction_10m'];
    final gusts = json['wind_gusts_10m'];
    return WeatherCurrent(
      time: parsed,
      temperature: temperature.toDouble(),
      humidity: humidity.round(),
      weatherCode: code.round(),
      windSpeed: wind.toDouble(),
      apparentTemperature: apparent is num ? apparent.toDouble() : null,
      isDay: isDay is num ? isDay != 0 : true,
      windDirection: direction is num ? direction.round() : null,
      windGusts: gusts is num ? gusts.toDouble() : null,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'time': time.toIso8601String(),
    'temperature_2m': temperature,
    'relative_humidity_2m': humidity,
    'weather_code': weatherCode,
    'wind_speed_10m': windSpeed,
    if (apparentTemperature != null)
      'apparent_temperature': apparentTemperature,
    'is_day': isDay ? 1 : 0,
    if (windDirection != null) 'wind_direction_10m': windDirection,
    if (windGusts != null) 'wind_gusts_10m': windGusts,
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

/// Condizioni previste per una singola ora (icona, probabilità, vento).
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.weatherCode,
    this.precipitationProbability,
    this.windSpeed,
    this.isDay = true,
  });

  final DateTime time;
  final int weatherCode;

  /// Probabilità di precipitazione (%), se disponibile.
  final int? precipitationProbability;

  /// Vento (km/h), se disponibile.
  final double? windSpeed;

  final bool isDay;
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
    this.sunrise,
    this.sunset,
    this.windSpeedMax,
    this.windGustsMax,
    this.precipitationHours,
    this.uvIndexMax,
  });

  final DateTime date;
  final int weatherCode;
  final double temperatureMin;
  final double temperatureMax;
  final double precipitationSum;

  /// Probabilità massima di precipitazione (%), se disponibile.
  final int? precipitationProbability;

  final DateTime? sunrise;
  final DateTime? sunset;

  /// Vento massimo (km/h) e raffiche massime (km/h).
  final double? windSpeedMax;
  final double? windGustsMax;

  /// Ore con precipitazione nella giornata.
  final double? precipitationHours;

  final double? uvIndexMax;
}

/// Insieme dei dati meteo scaricati.
class WeatherData {
  const WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAtUtc,
    this.hourlyTemperature = const [],
    this.hourlyForecast = const [],
    this.dailyReliability = const {},
    this.reliability48h,
    this.locationId = 543,
  });

  final WeatherCurrent current;

  /// Precipitazioni orarie, passato incluso (past_days).
  final List<HourlyPrecipitation> hourly;

  /// Temperature orarie, passato incluso.
  final List<HourlyTemperature> hourlyTemperature;

  /// Condizioni orarie (codice meteo, probabilità, vento).
  final List<HourlyForecast> hourlyForecast;

  final List<DailyForecast> daily;

  final DateTime fetchedAtUtc;
  final int locationId;

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
      hourlyForecast: hourlyForecast,
      dailyReliability: daily,
      reliability48h: next48h,
      locationId: locationId,
    );
  }

  /// Parsa la risposta dell'API Open-Meteo (o la cache, stesso formato).
  static WeatherData? fromApiJson(
    Map<String, dynamic> json, {
    required DateTime fetchedAtUtc,
    int locationId = 543,
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
      locationId: locationId,
      // Dall'API tutte le serie orarie stanno in `hourly`; nella cache
      // sono separate (gli array possono avere lunghezze diverse).
      hourlyTemperature: _parseHourlyTemperature(
        json['hourly_temp'] ?? json['hourly'],
      ),
      hourlyForecast: _parseHourlyForecast(
        json['hourly_detail'] ?? json['hourly'],
      ),
      dailyReliability: _parseReliability(json['reliability_daily']),
      reliability48h: json['reliability_48h'] is num
          ? (json['reliability_48h'] as num).round()
          : null,
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
            HourlyTemperature(time: t, celsius: (values[i] as num).toDouble()),
    ];
  }

  static List<HourlyForecast> _parseHourlyForecast(dynamic hourly) {
    if (hourly is! Map<String, dynamic>) return const [];
    final times = hourly['time'];
    final codes = hourly['weather_code'];
    if (times is! List || codes is! List) return const [];
    final probs = hourly['precipitation_probability'];
    final winds = hourly['wind_speed_10m'];
    final days = hourly['is_day'];
    num? at(dynamic list, int i) =>
        list is List && i < list.length && list[i] is num
        ? list[i] as num
        : null;
    final length = times.length < codes.length ? times.length : codes.length;
    return [
      for (var i = 0; i < length; i++)
        if (times[i] is String && codes[i] is num)
          if (DateTime.tryParse(times[i] as String) case final t?)
            HourlyForecast(
              time: t,
              weatherCode: (codes[i] as num).round(),
              precipitationProbability: at(probs, i)?.round(),
              windSpeed: at(winds, i)?.toDouble(),
              isDay: switch (at(days, i)) {
                final d? => d != 0,
                null => true,
              },
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
    final sunrise = daily['sunrise'];
    final sunset = daily['sunset'];
    final windMax = daily['wind_speed_10m_max'];
    final gustsMax = daily['wind_gusts_10m_max'];
    final rainHours = daily['precipitation_hours'];
    final uv = daily['uv_index_max'];
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
    num? numAt(dynamic list, int i) =>
        list is List && i < list.length && list[i] is num
        ? list[i] as num
        : null;
    DateTime? dateAt(dynamic list, int i) =>
        list is List && i < list.length && list[i] is String
        ? DateTime.tryParse(list[i] as String)
        : null;
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
              precipitationProbability: numAt(prob, i)?.round(),
              sunrise: dateAt(sunrise, i),
              sunset: dateAt(sunset, i),
              windSpeedMax: numAt(windMax, i)?.toDouble(),
              windGustsMax: numAt(gustsMax, i)?.toDouble(),
              precipitationHours: numAt(rainHours, i)?.toDouble(),
              uvIndexMax: numAt(uv, i)?.toDouble(),
            ),
    ];
  }

  Map<String, dynamic> toCacheJson() => {
    'fetchedAt': fetchedAtUtc.toIso8601String(),
    'locationId': locationId,
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
      'time': [for (final h in hourlyTemperature) h.time.toIso8601String()],
      'temperature_2m': [for (final h in hourlyTemperature) h.celsius],
    },
    'hourly_detail': {
      'time': [for (final h in hourlyForecast) h.time.toIso8601String()],
      'weather_code': [for (final h in hourlyForecast) h.weatherCode],
      'precipitation_probability': [
        for (final h in hourlyForecast) h.precipitationProbability,
      ],
      'wind_speed_10m': [for (final h in hourlyForecast) h.windSpeed],
      'is_day': [for (final h in hourlyForecast) h.isDay ? 1 : 0],
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
      'sunrise': [for (final d in daily) d.sunrise?.toIso8601String()],
      'sunset': [for (final d in daily) d.sunset?.toIso8601String()],
      'wind_speed_10m_max': [for (final d in daily) d.windSpeedMax],
      'wind_gusts_10m_max': [for (final d in daily) d.windGustsMax],
      'precipitation_hours': [for (final d in daily) d.precipitationHours],
      'uv_index_max': [for (final d in daily) d.uvIndexMax],
    },
  };

  static WeatherData? fromCacheJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'];
    if (fetchedAt is! String) return null;
    final parsed = DateTime.tryParse(fetchedAt);
    if (parsed == null) return null;
    return fromApiJson(
      json,
      fetchedAtUtc: parsed.toUtc(),
      locationId: json['locationId'] is int ? json['locationId'] as int : 543,
    );
  }
}
