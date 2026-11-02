import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/threshold_colors.dart';
import '../../../data/models/osmer_bulletin.dart';
import '../../../data/models/weather_data.dart';
import '../../../data/models/weather_location.dart';
import '../../../data/repositories/weather_repository.dart';
import '../../../domain/services/forecast_reliability.dart';
import '../../../domain/services/weather_code.dart';
import '../../providers/weather_providers.dart';
import '../../widgets/data_status_banner.dart';
import '../../widgets/error_body.dart';
import 'climate_screen.dart';
import 'history_screen.dart';
import 'scenarios_screen.dart';

final _mmFormat = NumberFormat('0.0', 'it');
final _tempFormat = NumberFormat('0', 'it');
final _timeFormat = DateFormat('HH:mm');
final _hourFormat = DateFormat('HH');

/// Colore della concordanza tra scenari.
Color _reliabilityColor(int percent) {
  if (percent >= 80) return ThresholdColors.normal;
  if (percent >= 65) return ThresholdColors.soglia1;
  return ThresholdColors.soglia2;
}

/// Punto cardinale di provenienza del vento (gradi → sigla italiana).
String _compass(int degrees) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
  return points[((degrees + 22.5) % 360 ~/ 45)];
}

/// Schermata meteo: condizioni attuali, prossime ore, precipitazioni,
/// temperature, 7 giorni e bollettino OSMER.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherProvider);
    final selectedId = ref.watch(selectedWeatherLocationProvider);
    final location = weatherLocationById(selectedId);
    final agreement = ref.watch(forecastAgreementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meteo'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () => ref.read(weatherProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: DropdownButtonFormField<int>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Punto di previsione nel bacino',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final point in weatherLocations)
                  DropdownMenuItem(value: point.id, child: Text(point.name)),
              ],
              onChanged: (id) {
                if (id != null) {
                  ref.read(selectedWeatherLocationProvider.notifier).state = id;
                }
              },
            ),
          ),
          dataStatusBanner<WeatherResult>(
            state: state,
            fetchedAtUtc: (r) => r.data.fetchedAtUtc,
            newestMeasureUtc: (r) => r.data.fetchedAtUtc,
            fromCache: (r) => r.fromCache,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(weatherProvider.notifier).refresh(),
              child: switch (state) {
                AsyncValue(:final value?)
                    when value.data.locationId == selectedId =>
                  _WeatherBody(
                    result: value,
                    location: location,
                    agreement: agreement,
                  ),
                AsyncValue(hasError: true) => const ErrorBody(),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({
    required this.result,
    required this.location,
    this.agreement,
  });

  final WeatherResult result;
  final WeatherLocation location;
  final ReliabilityResult? agreement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = result.data;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentCard(data: data, location: location),
        const SizedBox(height: 12),
        _HourlyStripCard(data: data),
        const SizedBox(height: 12),
        _PrecipitationCard(data: data, agreement: agreement?.next48h),
        const SizedBox(height: 12),
        _TemperatureCard(data: data),
        const SizedBox(height: 12),
        _DailyCard(data: data, agreement: agreement?.daily ?? const {}),
        const SizedBox(height: 12),
        const _OsmerCard(),
        _SectionTitle('Approfondimenti'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.radar, color: theme.colorScheme.primary),
                title: const Text('Radar pioggia ufficiale'),
                subtitle: const Text('Precipitazioni in tempo reale (OSMER)'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => launchUrl(
                  Uri.parse('https://www.meteo.fvg.it/radar_tracking.php?ln='),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.history, color: theme.colorScheme.primary),
                title: const Text('Pioggia dal 1940'),
                subtitle: const Text(
                  'Pioggia annua, confronto con il clima e giorni record',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(
                  Icons.thermostat,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Temperature dal 1940'),
                subtitle: const Text(
                  'Riscaldamento climatico: anomalie, medie e giorni caldi',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ClimateScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Previsioni: Open-Meteo (open-meteo.com), punto di riferimento '
          '${location.name}. Sono stime su coordinate, non misure di un '
          'pluviometro. La concordanza degli scenari confronta i membri del '
          'modello ensemble (ICON) sull\'esito pioggia/non pioggia: 100% = '
          'scenari tutti concordi, 50% = scenari divisi. Non misura '
          'l\'accuratezza verificata della previsione. I dati passati sono '
          'stimati dal modello.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Titoletto di sezione tra gruppi di card.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Condizioni attuali: temperatura grande, percepita, vento, umidità,
/// alba e tramonto, su uno sfondo leggermente tinto dalla condizione.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.data, required this.location});

  final WeatherData data;
  final WeatherLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = data.current;
    final windDir = current.windDirection;
    final ui = WeatherCodeUi.describe(current.weatherCode, isDay: current.isDay);
    final today = DateTime(
      current.time.year,
      current.time.month,
      current.time.day,
    );
    DailyForecast? todayForecast;
    for (final d in data.daily) {
      if (d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day) {
        todayForecast = d;
        break;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ui.color.withValues(alpha: 0.18),
              theme.colorScheme.surfaceContainerLow.withValues(alpha: 0),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Adesso · ${location.name}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _timeFormat.format(current.time),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(ui.icon, size: 64, color: ui.color),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_tempFormat.format(current.temperature)}°',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(ui.label, style: theme.textTheme.titleSmall),
                        if (current.apparentTemperature case final felt?)
                          Text(
                            'Percepita ${_tempFormat.format(felt)}°',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatPill(
                    icon: Icons.air,
                    text:
                        '${_tempFormat.format(current.windSpeed)} km/h'
                        '${windDir == null ? '' : ' ${_compass(windDir)}'}',
                    trailing: windDir == null
                        ? null
                        : Transform.rotate(
                            // La freccia indica dove soffia il vento
                            // (la direzione API è quella di provenienza).
                            angle: (windDir + 180) * math.pi / 180,
                            child: Icon(
                              Icons.navigation,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (current.windGusts case final gusts? when gusts >= 20)
                    _StatPill(
                      icon: Icons.storm_outlined,
                      text: 'raffiche ${_tempFormat.format(gusts)} km/h',
                    ),
                  _StatPill(
                    icon: Icons.water_drop_outlined,
                    text: 'umidità ${current.humidity}%',
                  ),
                  if (todayForecast?.sunrise case final sunrise?)
                    _StatPill(
                      icon: Icons.wb_twilight,
                      text: 'alba ${_timeFormat.format(sunrise)}',
                    ),
                  if (todayForecast?.sunset case final sunset?)
                    _StatPill(
                      icon: Icons.nights_stay_outlined,
                      text: 'tramonto ${_timeFormat.format(sunset)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pillola icona + testo per i dati di contorno.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

/// Le prossime 24 ore, un'ora per colonna, a scorrimento orizzontale.
class _HourlyStripCard extends StatelessWidget {
  const _HourlyStripCard({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = data.current.time;
    final to = now.add(const Duration(hours: 24));
    final hours = [
      for (final h in data.hourlyForecast)
        if (h.time.isAfter(now) && !h.time.isAfter(to)) h,
    ];
    if (hours.length < 3) return const SizedBox.shrink();

    final tempByTime = {for (final t in data.hourlyTemperature) t.time: t.celsius};
    final mmByTime = {for (final p in data.hourly) p.time: p.millimeters};

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prossime 24 ore', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: hours.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final h = hours[i];
                  final ui = WeatherCodeUi.describe(h.weatherCode, isDay: h.isDay);
                  final temp = tempByTime[h.time];
                  final mm = mmByTime[h.time] ?? 0;
                  final prob = h.precipitationProbability ?? 0;
                  final isFirst = i == 0;
                  return Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.45,
                            )
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_hourFormat.format(h.time)}h',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isFirst ? FontWeight.bold : null,
                          ),
                        ),
                        Icon(ui.icon, size: 26, color: ui.color),
                        Text(
                          temp == null ? '—' : '${_tempFormat.format(temp)}°',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          prob >= 10
                              ? '$prob%'
                              : mm >= 0.1
                              ? '${_mmFormat.format(mm)} mm'
                              : ' ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: prob >= 10 || mm >= 0.1
                                ? WeatherCodeUi.describe(61).color
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pioggia caduta (ultime 24h) e prevista (prossime 48h).
class _PrecipitationCard extends StatelessWidget {
  const _PrecipitationCard({required this.data, this.agreement});

  final WeatherData data;
  final int? agreement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = data.current.time;
    final from = now.subtract(const Duration(hours: 24));
    final to = now.add(const Duration(hours: 48));

    // Finestra oraria: ultime 24h + prossime 48h.
    final window = [
      for (final h in data.hourly)
        if (!h.time.isBefore(from) && !h.time.isAfter(to)) h,
    ];
    if (window.isEmpty) return const SizedBox.shrink();

    var pastSum = 0.0;
    var futureSum = 0.0;
    var rainyHours = 0;
    var maxMm = 0.0;
    for (final h in window) {
      final mm = math.max(0.0, h.millimeters);
      if (h.time.isBefore(now)) {
        pastSum += mm;
      } else {
        futureSum += mm;
        if (mm >= 0.1) rainyHours++;
      }
      if (mm > maxMm) maxMm = mm;
    }
    var maxProb = 0;
    for (final h in data.hourlyForecast) {
      if (h.time.isAfter(now) && !h.time.isAfter(to)) {
        final p = h.precipitationProbability ?? 0;
        if (p > maxProb) maxProb = p;
      }
    }

    final pastColor = theme.colorScheme.outline;
    final futureColor = theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precipitazioni', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _SumChip(
                  color: pastColor,
                  label: 'stima ultime 24 ore',
                  text: '${_mmFormat.format(pastSum)} mm',
                ),
                const SizedBox(width: 12),
                _SumChip(
                  color: futureColor,
                  label: 'prossime 48 ore',
                  text: '${_mmFormat.format(futureSum)} mm',
                ),
              ],
            ),
            if (futureSum >= 0.1 || maxProb >= 10) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (rainyHours > 0)
                    'pioggia prevista per $rainyHours ${rainyHours == 1 ? 'ora' : 'ore'}',
                  if (maxProb >= 10) 'probabilità massima $maxProb%',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxMm < 1 ? 1 : maxMm * 1.2,
                  barGroups: [
                    for (final (i, h) in window.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0.0, h.millimeters),
                            width: 3,
                            borderRadius: BorderRadius.circular(1),
                            color: h.time.isBefore(now)
                                ? pastColor
                                : futureColor,
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) => Text(
                          _mmFormat.format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        // Nei BarChart l'interval non filtra le etichette:
                        // si mostra un orario ogni 12 barre.
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= window.length || i % 12 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _timeFormat.format(window[i].time),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final h = window[group.x];
                        return BarTooltipItem(
                          '${_timeFormat.format(h.time)}\n'
                          '${_mmFormat.format(h.millimeters)} mm',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'mm di pioggia per ora: grigio = stima del passato, '
              'blu = prevista',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (agreement case final rel?) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: _reliabilityColor(rel),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Concordanza degli scenari a 48 ore: $rel%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _reliabilityColor(rel),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScenariosScreen(),
                  ),
                ),
                icon: const Icon(Icons.insights, size: 18),
                label: const Text('Esplora gli scenari possibili'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SumChip extends StatelessWidget {
  const _SumChip({
    required this.color,
    required this.label,
    required this.text,
  });

  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Temperature: andamento nelle ultime 24 ore e nelle prossime 48.
class _TemperatureCard extends StatelessWidget {
  const _TemperatureCard({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = data.current.time;
    final from = now.subtract(const Duration(hours: 24));
    final to = now.add(const Duration(hours: 48));

    final window = [
      for (final h in data.hourlyTemperature)
        if (!h.time.isBefore(from) && !h.time.isAfter(to)) h,
    ];
    if (window.length < 2) return const SizedBox.shrink();

    var minFuture = double.infinity;
    var maxFuture = -double.infinity;
    var minAll = double.infinity;
    var maxAll = -double.infinity;
    for (final h in window) {
      if (h.celsius < minAll) minAll = h.celsius;
      if (h.celsius > maxAll) maxAll = h.celsius;
      if (!h.time.isBefore(now)) {
        if (h.celsius < minFuture) minFuture = h.celsius;
        if (h.celsius > maxFuture) maxFuture = h.celsius;
      }
    }

    final pastColor = theme.colorScheme.outline;
    final futureColor = theme.colorScheme.primary;

    // Due segmenti che condividono il punto di confine, così la
    // linea è continua ma il passato resta grigio.
    final pastSpots = <FlSpot>[];
    final futureSpots = <FlSpot>[];
    var nowIndex = 0;
    for (final (i, h) in window.indexed) {
      final spot = FlSpot(i.toDouble(), h.celsius);
      if (h.time.isBefore(now)) {
        pastSpots.add(spot);
      } else {
        if (futureSpots.isEmpty && pastSpots.isNotEmpty) {
          pastSpots.add(spot);
          nowIndex = i;
        }
        futureSpots.add(spot);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperature', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _SumChip(
                  color: futureColor,
                  label: 'minima prossime 48 ore',
                  text: '${_tempFormat.format(minFuture)}°',
                ),
                const SizedBox(width: 12),
                _SumChip(
                  color: ThresholdColors.soglia2,
                  label: 'massima prossime 48 ore',
                  text: '${_tempFormat.format(maxFuture)}°',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: (minAll - 2).floorToDouble(),
                  maxY: (maxAll + 2).ceilToDouble(),
                  lineBarsData: [
                    if (pastSpots.length >= 2)
                      LineChartBarData(
                        spots: pastSpots,
                        color: pastColor,
                        barWidth: 2,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        dotData: const FlDotData(show: false),
                      ),
                    if (futureSpots.length >= 2)
                      LineChartBarData(
                        spots: futureSpots,
                        color: futureColor,
                        barWidth: 2.5,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              futureColor.withValues(alpha: 0.18),
                              futureColor.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      if (nowIndex > 0)
                        VerticalLine(
                          x: nowIndex.toDouble(),
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.6,
                          ),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(left: 4, top: 2),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            labelResolver: (_) => 'ora',
                          ),
                        ),
                    ],
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) => Text(
                          '${_tempFormat.format(value)}°',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 12,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= window.length || i % 12 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _timeFormat.format(window[i].time),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${_timeFormat.format(window[s.x.toInt()].time)}\n'
                            '${_tempFormat.format(s.y)}°',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '°C per ora: grigio = ultime 24 ore, blu = previste',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bollettino ufficiale ARPA-OSMER per la zona di Sacile.
/// Se il bollettino non è disponibile la card non compare.
class _OsmerCard extends ConsumerWidget {
  const _OsmerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = ref.watch(osmerProvider).valueOrNull;
    if (result == null) return const SizedBox.shrink();
    final bulletin = result.bulletin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Il parere dei meteorologi',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Bollettino ARPA FVG — OSMER · zona Alta Pianura',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (bulletin.situazione.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bulletin.situazione,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
              for (final day in bulletin.days) _OsmerDayBlock(day: day),
              const SizedBox(height: 12),
              Text(
                'Emesso il '
                '${_dayTimeFormatOsmer.format(bulletin.issuedUtc.toLocal())}'
                '${result.fromCache ? ' (bollettino salvato)' : ''} · '
                'Fonte: ARPA FVG - OSMER e GRN, www.meteo.fvg.it '
                '(CC BY-SA 3.0 IT)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _dayTimeFormatOsmer = DateFormat('dd/MM HH:mm');
final _osmerDateFormat = DateFormat('EEE d MMMM', 'it');

class _OsmerDayBlock extends StatelessWidget {
  const _OsmerDayBlock({required this.day});

  final OsmerDay day;

  String get _label {
    final l = day.label.trim();
    if (l.isEmpty) return _osmerDateFormat.format(day.date);
    return '${l[0]}${l.substring(1).toLowerCase()} '
        '(${_osmerDateFormat.format(day.date)})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (day.attendibilita case final att?)
                Text(
                  'attendibilità $att%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _reliabilityColor(att),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            day.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Previsioni per i prossimi 7 giorni; ogni riga si espande con i dettagli.
class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.data, required this.agreement});

  final WeatherData data;
  final Map<DateTime, int> agreement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime(
      data.current.time.year,
      data.current.time.month,
      data.current.time.day,
    );
    final days = [
      for (final d in data.daily)
        if (!d.date.isBefore(today)) d,
    ];
    if (days.isEmpty) return const SizedBox.shrink();

    var weekMin = double.infinity;
    var weekMax = -double.infinity;
    for (final d in days) {
      if (d.temperatureMin < weekMin) weekMin = d.temperatureMin;
      if (d.temperatureMax > weekMax) weekMax = d.temperatureMax;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prossimi giorni', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Tocca un giorno per vento, sole e ore di pioggia.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            for (final (i, d) in days.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _DailyRow(
                forecast: d,
                dayIndex: i,
                weekMin: weekMin,
                weekMax: weekMax,
                reliability:
                    agreement[DateTime(d.date.year, d.date.month, d.date.day)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyRow extends StatefulWidget {
  const _DailyRow({
    required this.forecast,
    required this.dayIndex,
    required this.weekMin,
    required this.weekMax,
    this.reliability,
  });

  final DailyForecast forecast;
  final int dayIndex;
  final double weekMin;
  final double weekMax;

  /// Concordanza (%) degli scenari per questo giorno, se nota.
  final int? reliability;

  @override
  State<_DailyRow> createState() => _DailyRowState();
}

class _DailyRowState extends State<_DailyRow> {
  bool _expanded = false;

  String get _dayLabel => switch (widget.dayIndex) {
    0 => 'Oggi',
    1 => 'Domani',
    _ => DateFormat('EEE d', 'it').format(widget.forecast.date),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.forecast;
    final ui = WeatherCodeUi.describe(f.weatherCode);
    final prob = f.precipitationProbability;
    final rainText = f.precipitationSum >= 0.1 || (prob ?? 0) >= 10
        ? '${_mmFormat.format(f.precipitationSum)} mm'
              '${prob == null ? '' : ' · $prob%'}'
        : 'asciutto';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    _dayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: widget.dayIndex == 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(ui.icon, size: 24, color: ui.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.reliability case final rel?)
                        Text(
                          'concordanza $rel%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _reliabilityColor(rel),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TempRange(
                  min: f.temperatureMin,
                  max: f.temperatureMax,
                  weekMin: widget.weekMin,
                  weekMax: widget.weekMax,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10, left: 64),
                      child: _DailyDetails(forecast: f, label: ui.label),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dettagli del giorno: condizione, vento, ore di pioggia, UV, sole.
class _DailyDetails extends StatelessWidget {
  const _DailyDetails({required this.forecast, required this.label});

  final DailyForecast forecast;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = forecast;
    final wind = f.windSpeedMax;
    final gusts = f.windGustsMax;
    final rows = <(IconData, String)>[
      (Icons.wb_cloudy_outlined, label),
      if (wind != null)
        (
          Icons.air,
          'Vento fino a ${_tempFormat.format(wind)} km/h'
              '${gusts != null && gusts >= wind + 5 ? ', raffiche ${_tempFormat.format(gusts)} km/h' : ''}',
        ),
      if (f.precipitationHours case final hours? when hours >= 1)
        (
          Icons.umbrella_outlined,
          'Pioggia per circa ${hours.round()} ${hours.round() == 1 ? 'ora' : 'ore'}',
        ),
      if (f.uvIndexMax case final uv? when uv >= 3)
        (Icons.wb_sunny_outlined, 'Indice UV massimo ${_tempFormat.format(uv)}'),
      if (f.sunrise case final rise?)
        if (f.sunset case final set?)
          (
            Icons.wb_twilight,
            'Alba ${_timeFormat.format(rise)} · tramonto ${_timeFormat.format(set)}',
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Minima e massima del giorno con una barra posizionata rispetto
/// all'escursione dell'intera settimana.
class _TempRange extends StatelessWidget {
  const _TempRange({
    required this.min,
    required this.max,
    required this.weekMin,
    required this.weekMax,
  });

  final double min;
  final double max;
  final double weekMin;
  final double weekMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final span = math.max(1.0, weekMax - weekMin);
    final start = ((min - weekMin) / span).clamp(0.0, 1.0);
    final end = ((max - weekMin) / span).clamp(0.0, 1.0);
    const barWidth = 54.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${_tempFormat.format(min)}°',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: barWidth,
          height: 6,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: start * barWidth,
                width: math.max(6, (end - start) * barWidth),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFFFF7043)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text(
            '${_tempFormat.format(max)}°',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
