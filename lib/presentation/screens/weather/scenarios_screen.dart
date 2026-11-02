import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/services/scenario_analysis.dart';
import '../../providers/weather_providers.dart';
import '../../widgets/error_body.dart';
import '../../widgets/data_status_banner.dart';
import '../../../data/repositories/ensemble_repository.dart';

final _mmFormat = NumberFormat('#,##0', 'it');
final _dayFormat = DateFormat('EEE d', 'it');

/// Pagina degli scenari ensemble: come possono andare i prossimi
/// 7 giorni di pioggia secondo i ~40 scenari del modello.
class ScenariosScreen extends ConsumerWidget {
  const ScenariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scenarioProvider);
    final location = weatherLocationById(
      ref.watch(selectedWeatherLocationProvider),
    );
    final ensembleState = ref.watch(ensembleForLocationProvider(location.id));

    Future<void> refresh() async {
      try {
        await refreshEnsemble(ref);
      } catch (_) {
        ref.invalidate(ensembleForLocationProvider(location.id));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenari di pioggia'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          dataStatusBanner<EnsembleResult>(
            state: ensembleState,
            fetchedAtUtc: (r) => r.fetchedAtUtc,
            newestMeasureUtc: (r) => r.fetchedAtUtc,
            fromCache: (r) => r.isOfflineFallback,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: switch (state) {
                AsyncValue(:final value?) => _ScenariosBody(
                  result: value,
                  locationName: location.name,
                ),
                AsyncValue(hasValue: true) ||
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

class _ScenariosBody extends StatelessWidget {
  const _ScenariosBody({required this.result, required this.locationName});

  final ScenarioResult result;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Pioggia nelle prossime ${result.horizonHours} ore · $locationName',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Il modello meteo viene fatto girare ${result.memberCount} volte '
          'con condizioni di partenza leggermente diverse: ne escono '
          '${result.memberCount} scenari possibili. Quando gli scenari '
          'sono vicini concordano maggiormente; quando divergono, '
          'gli esiti possibili sono più diversi. La concordanza non '
          'misura l\'accuratezza verificata del modello.'
          '${result.memberCount < result.totalMemberCount ? ' Sono esclusi i membri con dati incompleti.' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _FanChartCard(result: result),
        const SizedBox(height: 12),
        _ScenarioSummaryCard(result: result),
        const SizedBox(height: 12),
        _ThresholdCard(result: result),
        const SizedBox(height: 12),
        Text(
          'Pioggia cumulata prevista per $locationName nelle prossime '
          '${result.horizonHours} ore, '
          'modello ensemble ICON via Open-Meteo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Grafico a ventaglio: mediana + bande 25–75 e 10–90.
class _FanChartCard extends StatelessWidget {
  const _FanChartCard({required this.result});

  final ScenarioResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    List<FlSpot> spots(List<double> values) => [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    LineChartBarData invisible(List<double> values) => LineChartBarData(
      spots: spots(values),
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );

    final maxY = result.p90.last < 5 ? 5.0 : result.p90.last * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Il ventaglio degli scenari',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    invisible(result.p10), // 0
                    invisible(result.p90), // 1
                    invisible(result.p25), // 2
                    invisible(result.p75), // 3
                    LineChartBarData(
                      spots: spots(result.p50),
                      color: primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  betweenBarsData: [
                    BetweenBarsData(
                      fromIndex: 0,
                      toIndex: 1,
                      color: primary.withValues(alpha: 0.10),
                    ),
                    BetweenBarsData(
                      fromIndex: 2,
                      toIndex: 3,
                      color: primary.withValues(alpha: 0.18),
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
                        reservedSize: 40,
                        // L'etichetta del massimo si sovrappone all'ultima
                        // della griglia regolare.
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
                        interval: 48,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          // fl_chart aggiunge sempre l'etichetta al bordo
                          // destro: si tiene solo la griglia dell'interval.
                          if (i < 0 ||
                              i >= result.times.length ||
                              i % 48 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _dayFormat.format(result.times[i]),
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
            Text(
              'Linea: scenario mediano. Banda scura: metà centrale degli '
              'scenari (25°–75° percentile). Banda chiara: 8 scenari su 10 '
              '(10°–90°).',
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

/// I tre scenari di sintesi.
class _ScenarioSummaryCard extends StatelessWidget {
  const _ScenarioSummaryCard({required this.result});

  final ScenarioResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tre scenari in sintesi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _ScenarioRow(
              icon: Icons.wb_sunny_outlined,
              color: const Color(0xFFF9A825),
              title: 'Se va verso l\'asciutto',
              subtitle:
                  '1 scenario su 10 prevede meno di '
                  '${_mmFormat.format(result.dryTotal)} mm in ${result.horizonHours} ore',
            ),
            const SizedBox(height: 10),
            _ScenarioRow(
              icon: Icons.water_drop_outlined,
              color: theme.colorScheme.primary,
              title: 'Scenario centrale',
              subtitle:
                  'La metà degli scenari si colloca attorno a '
                  '${_mmFormat.format(result.medianTotal)} mm',
            ),
            const SizedBox(height: 10),
            _ScenarioRow(
              icon: Icons.thunderstorm_outlined,
              color: const Color(0xFF1565C0),
              title: 'Se va verso il piovoso',
              subtitle:
                  '1 scenario su 10 supera '
                  '${_mmFormat.format(result.wetTotal)} mm in ${result.horizonHours} ore',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Probabilità di superare soglie di cumulata rilevanti per le piene.
class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.result});

  final ScenarioResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = result.exceedanceProbability.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scenari che raggiungono almeno, in ${result.horizonHours} ore:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final e in entries) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${e.value}%',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text('${e.key} mm', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
