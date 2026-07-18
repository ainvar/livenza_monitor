import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/threshold_colors.dart';
import '../../../data/models/level_data.dart';
import '../../../data/repositories/level_repository.dart';
import '../../../domain/services/alert_service.dart';
import '../../providers/level_providers.dart';
import '../../widgets/data_status_banner.dart';
import '../../widgets/error_body.dart';
import '../../widgets/regional_alert_card.dart';
import 'amarcord_screen.dart';

final _meterFormat = NumberFormat('0.00', 'it');
final _timeFormat = DateFormat('HH:mm');
final _dayTimeFormat = DateFormat('dd/MM HH:mm');

/// Schermata principale: livello del Livenza a Sacile.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(levelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livenza a Sacile'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () => ref.read(levelProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBanner(state),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(levelProvider.notifier).refresh(),
              child: switch (state) {
                AsyncValue(:final value?) => _LevelBody(result: value),
                AsyncValue(hasError: true) => const ErrorBody(),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(AsyncValue<LevelResult> state) {
    return dataStatusBanner<LevelResult>(
      state: state,
      fetchedAtUtc: (r) => r.data.fetchedAtUtc,
      newestMeasureUtc: (r) => r.data.latest?.timestampUtc,
      fromCache: (r) => r.fromCache,
    );
  }
}

/// Corpo con i dati: livello attuale, soglie e grafico.
class _LevelBody extends ConsumerWidget {
  const _LevelBody({required this.result});

  final LevelResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertService = ref.watch(alertServiceProvider);
    final data = result.data;
    final latest = data.latest;
    final alert = alertService.classify(latest?.value);
    final trend = alertService.trend(data.history);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const RegionalAlertCard(),
        _CurrentLevelCard(data: data, alert: alert, trend: trend),
        const SizedBox(height: 12),
        _ThresholdsCard(currentAlert: alert),
        const SizedBox(height: 12),
        _ChartCard(data: data),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.auto_stories,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Le grandi piene del Livenza'),
            subtitle: const Text(
              'Dal 1966 a oggi: la memoria del fiume nei dati',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AmarcordScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fonte: Protezione Civile FVG — rete di monitoraggio '
          '(stazione di Sacile, dati non validati)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Card principale con il livello attuale.
class _CurrentLevelCard extends StatelessWidget {
  const _CurrentLevelCard({
    required this.data,
    required this.alert,
    required this.trend,
  });

  final LevelData data;
  final AlertLevel alert;
  final LevelTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = data.latest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Livello attuale', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              latest == null ? '—' : '${_meterFormat.format(latest.value)} m',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: alert.color,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                alert.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: alert.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trend.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(trend.label, style: theme.textTheme.bodyMedium),
                if (latest != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'misura delle '
                    '${_timeFormat.format(latest.timestampLocal)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

/// Card con le soglie di allerta.
class _ThresholdsCard extends StatelessWidget {
  const _ThresholdsCard({required this.currentAlert});

  final AlertLevel currentAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soglie di allerta', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _ThresholdRow(
              color: ThresholdColors.soglia1,
              label: 'Allerta gialla',
              value: AppConfig.sogliaGialla,
              highlighted: currentAlert == AlertLevel.yellow,
            ),
            const SizedBox(height: 8),
            _ThresholdRow(
              color: ThresholdColors.soglia3,
              label: 'Allerta rossa',
              value: AppConfig.sogliaRossa,
              highlighted: currentAlert == AlertLevel.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.color,
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final Color color;
  final String label;
  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: highlighted ? FontWeight.bold : null,
            ),
          ),
        ),
        Text(
          'da ${_meterFormat.format(value)} m',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Card con il grafico delle ultime 48 ore.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final LevelData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = data.history;

    if (history.length < 2) {
      return const SizedBox.shrink();
    }

    final spots = [
      for (final m in history)
        FlSpot(m.timestampUtc.millisecondsSinceEpoch.toDouble(), m.value),
    ];

    final values = [for (final m in history) m.value];
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);

    // Range Y: segue i dati; se il livello si avvicina alle soglie,
    // estende il grafico per renderle visibili.
    final minY = (dataMin - 0.3).clamp(0.0, double.infinity);
    var maxY = dataMax + 0.3;
    if (dataMax >= AppConfig.sogliaGialla - 1.0) {
      maxY = AppConfig.sogliaRossa + 0.4;
    }

    final showThresholds = maxY >= AppConfig.sogliaGialla;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Ultime 48 ore',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: theme.colorScheme.primary,
                      barWidth: 2.5,
                      isCurved: false,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (showThresholds) ...[
                        _thresholdLine(
                          AppConfig.sogliaGialla,
                          ThresholdColors.soglia1,
                        ),
                        _thresholdLine(
                          AppConfig.sogliaRossa,
                          ThresholdColors.soglia3,
                        ),
                      ],
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
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          _meterFormat.format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: const Duration(hours: 12)
                            .inMilliseconds
                            .toDouble(),
                        getTitlesWidget: (value, meta) {
                          final t = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                            isUtc: true,
                          ).toLocal();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _timeFormat.format(t),
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
                            '${_dayTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt(), isUtc: true).toLocal())}\n'
                            '${_meterFormat.format(s.y)} m',
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
          ],
        ),
      ),
    );
  }

  HorizontalLine _thresholdLine(double y, Color color) {
    return HorizontalLine(
      y: y,
      color: color,
      strokeWidth: 1.5,
      dashArray: [6, 4],
    );
  }
}

