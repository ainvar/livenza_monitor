import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/weather_history.dart';
import '../../../data/repositories/history_repository.dart';
import '../../providers/history_providers.dart';
import '../../widgets/error_body.dart';

final _mmFormat = NumberFormat('#,##0', 'it');
final _mmFineFormat = NumberFormat('0.0', 'it');
final _dateFormat = DateFormat('dd/MM/yyyy');

/// Giorno dell'anno a fine di ciascun mese (anno non bisestile:
/// approssimazione sufficiente per il grafico).
const _monthEndDays = [31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365];

/// Sezione Storico: 86 anni di precipitazioni a Sacile (ERA5).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pioggia dal ${AppConfig.historyStartYear}'),
        actions: [
          IconButton(
            tooltip: 'Riscarica la serie',
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyProvider.notifier).refresh(),
        child: switch (state) {
          AsyncValue(:final value?) => _HistoryBody(result: value),
          AsyncValue(hasError: true) => const ErrorBody(),
          _ => const _LoadingBody(),
        },
      ),
    );
  }
}

/// Il primo download è grande: il caricamento merita una spiegazione.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Scaricamento di 86 anni di dati…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.result});

  final HistoryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = result.data;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentVsClimateCard(data: data),
        const SizedBox(height: 12),
        _AnnualCard(data: data),
        const SizedBox(height: 12),
        _RecordsCard(data: data),
        const SizedBox(height: 12),
        Text(
          'Fonte: rianalisi ERA5 (Copernicus/ECMWF) via Open-Meteo, '
          'licenza CC BY 4.0. Valori ricostruiti su griglia per il punto '
          'di Sacile, non misure di stazione. '
          'Dati fino al ${_dateFormat.format(data.lastDataDate)}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Cumulata dell'anno corrente confrontata con la media climatica.
class _CurrentVsClimateCard extends StatelessWidget {
  const _CurrentVsClimateCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = data.currentYearCumulative;
    if (current.isEmpty || data.climatologyCumulative.length < 12) {
      return const SizedBox.shrink();
    }

    final climateColor = theme.colorScheme.outline;
    final currentColor = theme.colorScheme.primary;

    final climateSpots = [
      const FlSpot(0, 0),
      for (var m = 0; m < 12; m++)
        FlSpot(_monthEndDays[m].toDouble(), data.climatologyCumulative[m]),
    ];
    final currentSpots = [
      const FlSpot(0, 0),
      for (final p in current) FlSpot(p.dayOfYear.toDouble(), p.millimeters),
    ];

    final currentTotal = current.last.millimeters;
    final climateTotal = data.climatologyCumulative.last;
    var maxY = climateTotal;
    if (currentTotal > maxY) maxY = currentTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pioggia ${data.currentYear} vs clima',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Cumulata da inizio anno: '
              '${_mmFormat.format(currentTotal)} mm finora, contro '
              '${_mmFormat.format(climateTotal)} mm medi in un anno '
              'intero (${AppConfig.climatologyStartYear}–'
              '${AppConfig.climatologyEndYear}).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 366,
                  minY: 0,
                  maxY: maxY * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: climateSpots,
                      color: climateColor,
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: currentSpots,
                      color: currentColor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: currentColor.withValues(alpha: 0.10),
                      ),
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
                        reservedSize: 44,
                        maxIncluded: false,
                        getTitlesWidget: (value, meta) => Text(
                          _mmFormat.format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 61,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (day <= 0 || day > 365) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime(data.currentYear)
                              .add(Duration(days: day - 1));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('MMM', 'it').format(date),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(color: currentColor, label: '${data.currentYear}'),
                const SizedBox(width: 16),
                _LegendDot(
                  color: climateColor,
                  label: 'media ${AppConfig.climatologyStartYear}–'
                      '${AppConfig.climatologyEndYear}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Pioggia annua dal 1940.
class _AnnualCard extends StatelessWidget {
  const _AnnualCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = data.yearTotals;
    if (years.length < 2) return const SizedBox.shrink();

    var maxMm = 0.0;
    var sum = 0.0;
    for (final y in years) {
      if (y.millimeters > maxMm) maxMm = y.millimeters;
      sum += y.millimeters;
    }
    final mean = sum / years.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pioggia annua', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ogni barra è un anno (${years.first.year}–${years.last.year}). '
              'Media: ${_mmFormat.format(mean)} mm. Tocca per i valori.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxMm * 1.1,
                  barGroups: [
                    for (final y in years)
                      BarChartGroupData(
                        x: y.year,
                        barRods: [
                          BarChartRodData(
                            toY: y.millimeters,
                            width: 2.2,
                            borderRadius: BorderRadius.zero,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: mean,
                        color: theme.colorScheme.outline,
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                      ),
                    ],
                  ),
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
                        reservedSize: 44,
                        maxIncluded: false,
                        getTitlesWidget: (value, meta) => Text(
                          _mmFormat.format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        // Nei BarChart l'interval non filtra le etichette:
                        // si mostra solo un anno ogni 20, il resto è vuoto.
                        getTitlesWidget: (value, meta) {
                          final year = value.toInt();
                          if (year % 20 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$year',
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
                        return BarTooltipItem(
                          '${group.x}\n${_mmFormat.format(rod.toY)} mm',
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
          ],
        ),
      ),
    );
  }
}

/// I giorni più piovosi della serie.
class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.topDays.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I ${data.topDays.length} giorni più piovosi',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final (i, day) in data.topDays.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _dateFormat.format(day.date),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${_mmFineFormat.format(day.millimeters)} mm',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
