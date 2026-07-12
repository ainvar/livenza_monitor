import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/threshold_colors.dart';
import '../../../data/models/osmer_bulletin.dart';
import '../../../data/models/weather_data.dart';
import '../../../data/repositories/weather_repository.dart';
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

/// Colore dell'affidabilità: verde se alta, giallo/arancio se bassa.
Color _reliabilityColor(int percent) {
  if (percent >= 80) return ThresholdColors.normal;
  if (percent >= 65) return ThresholdColors.soglia1;
  return ThresholdColors.soglia2;
}

/// Schermata meteo: condizioni attuali, precipitazioni e 7 giorni.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherProvider);

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
                AsyncValue(:final value?) => _WeatherBody(result: value),
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
  const _WeatherBody({required this.result});

  final WeatherResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = result.data;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentCard(current: data.current),
        const SizedBox(height: 12),
        _PrecipitationCard(data: data),
        const SizedBox(height: 12),
        _DailyCard(data: data),
        const SizedBox(height: 12),
        const _OsmerCard(),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.history,
              color: theme.colorScheme.primary,
            ),
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
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
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
        ),
        const SizedBox(height: 12),
        Text(
          'Previsioni: Open-Meteo (open-meteo.com), punto di riferimento '
          'Sacile. Le precipitazioni sul bacino montano possono differire. '
          'L\'affidabilità è la concordanza tra i ~40 scenari del modello '
          'ensemble (ICON) sull\'esito pioggia/non pioggia: 100% = scenari '
          'tutti concordi, 50% = massima incertezza.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Condizioni attuali a Sacile.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.current});

  final WeatherCurrent current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = WeatherCodeUi.describe(current.weatherCode);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Adesso a Sacile', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ui.icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Text(
                  '${_tempFormat.format(current.temperature)}°',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(ui.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.air,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_tempFormat.format(current.windSpeed)} km/h',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.water_drop_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${current.humidity}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pioggia caduta (ultime 24h) e prevista (prossime 48h).
class _PrecipitationCard extends StatelessWidget {
  const _PrecipitationCard({required this.data});

  final WeatherData data;

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
    for (final h in window) {
      if (h.time.isBefore(now)) {
        pastSum += h.millimeters;
      } else {
        futureSum += h.millimeters;
      }
    }

    var maxMm = 0.0;
    for (final h in window) {
      if (h.millimeters > maxMm) maxMm = h.millimeters;
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
                  label: 'ultime 24 ore',
                  millimeters: pastSum,
                ),
                const SizedBox(width: 12),
                _SumChip(
                  color: futureColor,
                  label: 'prossime 48 ore',
                  millimeters: futureSum,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxMm < 1 ? 1 : maxMm * 1.2,
                  barGroups: [
                    for (final (i, h) in window.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: h.millimeters,
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
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
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
              'mm di pioggia per ora: grigio = già caduta, '
              'blu = prevista',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (data.reliability48h case final rel?) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: _reliabilityColor(rel),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Affidabilità della previsione a 48 ore: $rel%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _reliabilityColor(rel),
                      fontWeight: FontWeight.w600,
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
    required this.millimeters,
  });

  final Color color;
  final String label;
  final double millimeters;

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
              '${_mmFormat.format(millimeters)} mm',
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

/// Previsioni per i prossimi 7 giorni.
class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.data});

  final WeatherData data;

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prossimi giorni', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (i, d) in days.indexed)
              _DailyRow(
                forecast: d,
                dayIndex: i,
                reliability: data.dailyReliability[DateTime(
                  d.date.year,
                  d.date.month,
                  d.date.day,
                )],
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.forecast,
    required this.dayIndex,
    this.reliability,
  });

  final DailyForecast forecast;
  final int dayIndex;

  /// Affidabilità (%) della previsione per questo giorno, se nota.
  final int? reliability;

  String get _dayLabel => switch (dayIndex) {
        0 => 'Oggi',
        1 => 'Domani',
        _ => DateFormat('EEE dd/MM', 'it').format(forecast.date),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ui = WeatherCodeUi.describe(forecast.weatherCode);
    final prob = forecast.precipitationProbability;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              _dayLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: dayIndex == 0 ? FontWeight.bold : null,
              ),
            ),
          ),
          Tooltip(
            message: ui.label,
            child: Icon(ui.icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast.precipitationSum > 0 || (prob ?? 0) > 0
                      ? '${_mmFormat.format(forecast.precipitationSum)} mm'
                          '${prob == null ? '' : ' · $prob%'}'
                      : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (reliability case final rel?)
                  Text(
                    'affidabilità $rel%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _reliabilityColor(rel),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${_tempFormat.format(forecast.temperatureMin)}° / '
            '${_tempFormat.format(forecast.temperatureMax)}°',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
