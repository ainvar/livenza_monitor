import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/weather_history.dart';
import '../../../data/repositories/history_repository.dart';
import '../../providers/history_providers.dart';
import '../../widgets/error_body.dart';

final _degFormat = NumberFormat('0.0', 'it');
final _dateFormat = DateFormat('dd/MM/yyyy');

/// Colori delle anomalie termiche (convenzione: caldo rosso, freddo blu).
const _warmColor = Color(0xFFC62828);
const _coldColor = Color(0xFF1565C0);

/// Sezione Temperature: 86 anni di temperature a Sacile,
/// pensata per leggere il riscaldamento climatico locale.
class ClimateScreen extends ConsumerWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Temperature dal ${AppConfig.historyStartYear}'),
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
          AsyncValue(:final value?) => _ClimateBody(result: value),
          AsyncValue(hasError: true) => const ErrorBody(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ClimateBody extends StatelessWidget {
  const _ClimateBody({required this.result});

  final HistoryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = result.data;

    if (data.annualMeanTemp.length < 2) {
      return const ErrorBody();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _AnomalyCard(data: data),
        const SizedBox(height: 12),
        _MeanTempCard(data: data),
        const SizedBox(height: 12),
        _HotDaysCard(data: data),
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

/// Etichetta dell'asse anni: una ogni 20, il resto vuoto
/// (nei BarChart l'interval non filtra le etichette).
Widget _yearTitle(BuildContext context, double value) {
  final year = value.toInt();
  if (year % 20 != 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text('$year', style: Theme.of(context).textTheme.labelSmall),
  );
}

/// Anomalia della temperatura media annua rispetto alla baseline.
class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final anomalies = [
      for (final t in data.annualMeanTemp)
        YearValue(year: t.year, value: t.value - data.baselineTemp),
    ];
    var maxAbs = 0.0;
    for (final a in anomalies) {
      if (a.value.abs() > maxAbs) maxAbs = a.value.abs();
    }
    final lastDecadeMean = _meanOfLastYears(anomalies, 10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anomalia termica annua', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Differenza di ogni anno dalla media '
              '${AppConfig.baselineStartYear}–${AppConfig.baselineEndYear} '
              '(${_degFormat.format(data.baselineTemp)} °C). '
              'Ultimo decennio: ${_signed(lastDecadeMean)} °C.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  minY: -maxAbs * 1.15,
                  maxY: maxAbs * 1.15,
                  barGroups: [
                    for (final a in anomalies)
                      BarChartGroupData(
                        x: a.year,
                        barRods: [
                          BarChartRodData(
                            toY: a.value,
                            width: 2.2,
                            borderRadius: BorderRadius.zero,
                            color: a.value >= 0 ? _warmColor : _coldColor,
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 0
                          ? theme.colorScheme.outline
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.4),
                      strokeWidth: value == 0 ? 1.5 : 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          _signed(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) =>
                            _yearTitle(context, value),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${group.x}\n${_signed(rod.toY)} °C',
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

/// Temperatura media annua con media mobile decennale.
class _MeanTempCard extends StatelessWidget {
  const _MeanTempCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final temps = data.annualMeanTemp;

    var minT = temps.first.value;
    var maxT = temps.first.value;
    for (final t in temps) {
      if (t.value < minT) minT = t.value;
      if (t.value > maxT) maxT = t.value;
    }

    // Media mobile sugli ultimi 10 anni (finestra a ritroso).
    final movingAverage = <FlSpot>[];
    for (var i = 9; i < temps.length; i++) {
      var sum = 0.0;
      for (var j = i - 9; j <= i; j++) {
        sum += temps[j].value;
      }
      movingAverage.add(FlSpot(temps[i].year.toDouble(), sum / 10));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperatura media annua', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Punti annuali e media mobile su 10 anni (linea spessa). '
              'Da ${_degFormat.format(temps.first.value)} °C nel '
              '${temps.first.year} a ${_degFormat.format(temps.last.value)} '
              '°C nel ${temps.last.year}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: minT - 0.5,
                  maxY: maxT + 0.5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (final t in temps)
                          FlSpot(t.year.toDouble(), t.value),
                      ],
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: movingAverage,
                      color: _warmColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
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
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          _degFormat.format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 20,
                        getTitlesWidget: (value, meta) =>
                            _yearTitle(context, value),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giorni molto caldi per anno.
class _HotDaysCard extends StatelessWidget {
  const _HotDaysCard({required this.data});

  final WeatherHistory data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hotDays = data.hotDays;
    if (hotDays.length < 2) return const SizedBox.shrink();

    var maxDays = 0.0;
    for (final h in hotDays) {
      if (h.value > maxDays) maxDays = h.value;
    }
    final firstDecade = _meanOfFirstYears(hotDays, 10);
    final lastDecade = _meanOfLastYears(hotDays, 10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giorni con massima ≥ '
              '${_degFormat.format(AppConfig.hotDayThreshold)} °C',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Media nel primo decennio della serie: '
              '${firstDecade.round()} giorni/anno; '
              'nell\'ultimo: ${lastDecade.round()} giorni/anno.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxDays * 1.1,
                  barGroups: [
                    for (final h in hotDays)
                      BarChartGroupData(
                        x: h.year,
                        barRods: [
                          BarChartRodData(
                            toY: h.value,
                            width: 2.2,
                            borderRadius: BorderRadius.zero,
                            color: _warmColor,
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
                          '${value.toInt()}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) =>
                            _yearTitle(context, value),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${group.x}\n${rod.toY.round()} giorni',
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

String _signed(double value) =>
    '${value >= 0 ? '+' : '−'}${_degFormat.format(value.abs())}';

double _meanOfLastYears(List<YearValue> values, int n) {
  final slice = values.length <= n ? values : values.sublist(values.length - n);
  if (slice.isEmpty) return 0;
  var sum = 0.0;
  for (final v in slice) {
    sum += v.value;
  }
  return sum / slice.length;
}

double _meanOfFirstYears(List<YearValue> values, int n) {
  final slice = values.length <= n ? values : values.sublist(0, n);
  if (slice.isEmpty) return 0;
  var sum = 0.0;
  for (final v in slice) {
    sum += v.value;
  }
  return sum / slice.length;
}
