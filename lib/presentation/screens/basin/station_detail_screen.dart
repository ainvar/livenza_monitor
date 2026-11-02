import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/basin_reading.dart';
import '../../../data/models/basin_station.dart';
import '../../../data/models/hydro_measure.dart';
import '../../../data/repositories/station_history_repository.dart';
import '../../../domain/services/alert_service.dart';
import '../../providers/level_providers.dart';
import '../../providers/station_history_provider.dart';
import '../../widgets/favorite_station_button.dart';
import '../../widgets/station_freshness.dart';

final _levelFormat = NumberFormat('0.00', 'it');
final _deltaFormat = NumberFormat('+0.0;-0.0', 'it');
final _dateFormat = DateFormat('dd/MM HH:mm', 'it');

/// Dettaglio indipendente, apribile anche dalla Home per una stazione preferita.
class StationDetailScreen extends ConsumerStatefulWidget {
  const StationDetailScreen({
    super.key,
    required this.station,
    this.initialReading,
  });

  final BasinStation station;
  final BasinReading? initialReading;

  @override
  ConsumerState<StationDetailScreen> createState() =>
      _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen> {
  int _hours = 48;

  Future<void> _refresh() async {
    ref.invalidate(stationHistoryProvider(widget.station.id));
    try {
      await ref.read(stationHistoryProvider(widget.station.id).future);
    } catch (_) {
      // L'errore è presentato nel corpo, con un'azione per riprovare.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationHistoryProvider(widget.station.id));
    final result = state.valueOrNull;
    var latest = result?.data.latest;
    final initial = widget.initialReading;
    if (initial != null &&
        (latest == null || initial.timestampUtc.isAfter(latest.timestampUtc))) {
      latest = HydroMeasure(
        timestampUtc: initial.timestampUtc,
        value: initial.value,
      );
    }
    final theme = Theme.of(context);
    final alert = widget.station.isReference && latest != null
        ? ref.watch(alertServiceProvider).classify(latest.value)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.station.name),
        actions: [
          FavoriteStationButton(station: widget.station),
          IconButton(
            tooltip: 'Aggiorna storico',
            onPressed: state.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.station.river, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ultima lettura disponibile',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      latest == null
                          ? '—'
                          : '${_levelFormat.format(latest.value)} m',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: alert?.color,
                      ),
                    ),
                    if (latest != null) ...[
                      const SizedBox(height: 4),
                      Text(_dateFormat.format(latest.timestampLocal)),
                    ],
                    const SizedBox(height: 8),
                    StationFreshness(timestampUtc: latest?.timestampUtc),
                    if (alert != null) ...[
                      const SizedBox(height: 8),
                      Text(alert.label, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 6, label: Text('6 ore')),
                ButtonSegment(value: 24, label: Text('24 ore')),
                ButtonSegment(value: 48, label: Text('48 ore')),
              ],
              selected: {_hours},
              onSelectionChanged: (selected) =>
                  setState(() => _hours = selected.single),
            ),
            const SizedBox(height: 16),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.hasError && result == null)
              _HistoryMessage(
                message:
                    'Storico non disponibile. Controlla la connessione e riprova.',
                onRetry: _refresh,
              )
            else if (result != null)
              _HistoryContent(result: result, hours: _hours, onRetry: _refresh),
            const SizedBox(height: 16),
            Text(
              'Metri rispetto allo zero idrometrico di questa stazione: '
              'i livelli assoluti non sono confrontabili tra stazioni. '
              'Fonte: Protezione Civile FVG, dati non validati.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.result,
    required this.hours,
    required this.onRetry,
  });

  final StationHistoryResult result;
  final int hours;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final latest = result.data.latest;
    if (latest == null) {
      return _HistoryMessage(
        message:
            'La fonte non ha restituito misure nelle ultime 48 ore per questa stazione.',
        onRetry: onRetry,
      );
    }
    final from = latest.timestampUtc.subtract(Duration(hours: hours));
    final window = result.data.history
        .where((m) => !m.timestampUtc.isBefore(from))
        .toList();
    final theme = Theme.of(context);
    final duration = latest.timestampUtc.difference(window.first.timestampUtc);
    final elapsed = duration.inHours > 0
        ? '${duration.inHours} h ${duration.inMinutes.remainder(60)} min'
        : '${duration.inMinutes} min';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.fromCache) ...[
          _HistoryMessage(
            message:
                'Aggiornamento non riuscito: storico salvato il '
                '${_dateFormat.format(result.data.fetchedAtUtc.toLocal())}.',
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Finestra di $hours ore fino al ${_dateFormat.format(latest.timestampLocal)}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (window.length >= 2) ...[
          Text(
            '${_deltaFormat.format((latest.value - window.first.value) * 100)} cm '
            'fra la prima e l’ultima misura ($elapsed)',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          StationHistoryChart(measures: window),
          const SizedBox(height: 8),
          Text(
            'Le interruzioni indicano più di 45 minuti senza misure.',
            style: theme.textTheme.labelSmall,
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Una sola misura nel periodo: variazione e grafico non disponibili.',
            ),
          ),
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    ),
  );
}

/// Grafico di una sola stazione, senza interpolare buchi nella serie.
class StationHistoryChart extends StatelessWidget {
  const StationHistoryChart({super.key, required this.measures});
  final List<HydroMeasure> measures;

  @override
  Widget build(BuildContext context) {
    if (measures.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final spots = <FlSpot>[];
    HydroMeasure? previous;
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final measure in measures) {
      if (previous != null &&
          measure.timestampUtc.difference(previous.timestampUtc) >
              const Duration(minutes: 45)) {
        spots.add(FlSpot.nullSpot);
      }
      spots.add(
        FlSpot(
          measure.timestampUtc.millisecondsSinceEpoch.toDouble(),
          measure.value,
        ),
      );
      if (measure.value < min) min = measure.value;
      if (measure.value > max) max = measure.value;
      previous = measure;
    }
    final span = measures.last.timestampUtc.difference(
      measures.first.timestampUtc,
    );
    final padding = ((max - min) * .15).clamp(.05, double.infinity);
    return Semantics(
      label:
          'Andamento di ${measures.length} misure. '
          'Minimo ${_levelFormat.format(min)} metri, massimo ${_levelFormat.format(max)} metri.',
      child: SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            minY: min - padding,
            maxY: max + padding,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: theme.colorScheme.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: true),
              ),
            ],
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, _) => Text(
                    _levelFormat.format(value),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  minIncluded: false,
                  maxIncluded: false,
                  interval: (span.inMilliseconds.toDouble() / 3).clamp(
                    60000,
                    double.infinity,
                  ),
                  getTitlesWidget: (value, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd/MM\nHH:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          value.toInt(),
                          isUtc: true,
                        ).toLocal(),
                      ),
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt(), isUtc: true).toLocal())}\n${_levelFormat.format(spot.y)} m',
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
    );
  }
}
