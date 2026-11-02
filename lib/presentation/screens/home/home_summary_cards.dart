import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/basin_station.dart';
import '../../../data/models/level_data.dart';
import '../../../domain/services/level_insights.dart';
import '../../../domain/services/weather_code.dart';
import '../../providers/basin_providers.dart';
import '../../providers/favorite_stations_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/weather_providers.dart';
import '../basin/station_detail_screen.dart';

final _meters = NumberFormat('0.00', 'it');
final _centimeters = NumberFormat('0', 'it');
final _date = DateFormat('dd/MM HH:mm');

class LevelInsightsCard extends StatelessWidget {
  const LevelInsightsCard({super.key, required this.data});
  final LevelData data;

  @override
  Widget build(BuildContext context) {
    const insights = LevelInsights();
    final peak = insights.peak(data.history);
    final latest = data.latest;
    String delta(Duration window) {
      final value = insights.change(data.history, window);
      if (value == null) return 'Dati insufficienti';
      final cm = value * 100;
      return '${cm >= 0.5 ? '+' : ''}${_centimeters.format(cm.abs() < 0.5 ? 0 : cm)} cm';
    }

    final distance = latest == null
        ? null
        : AppConfig.sogliaGialla - latest.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cosa sta cambiando',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  _Metric(
                    label: 'Nell’ultima ora',
                    value: delta(const Duration(hours: 1)),
                    width: (constraints.maxWidth - 12) / 2,
                  ),
                  _Metric(
                    label: 'Nelle ultime 6 ore',
                    value: delta(const Duration(hours: 6)),
                    width: (constraints.maxWidth - 12) / 2,
                  ),
                  _Metric(
                    label: 'Picco della serie (48 h)',
                    value: peak == null
                        ? '—'
                        : '${_meters.format(peak.value)} m',
                    detail: peak == null
                        ? null
                        : _date.format(peak.timestampLocal),
                    width: (constraints.maxWidth - 12) / 2,
                  ),
                  _Metric(
                    label: distance != null && distance <= 0
                        ? 'Soglia gialla indicativa'
                        : 'Alla soglia gialla indicativa',
                    value: distance == null
                        ? '—'
                        : distance <= 0
                        ? 'Raggiunta'
                        : '${_centimeters.format(distance * 100)} cm',
                    width: (constraints.maxWidth - 12) / 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Variazioni riferite all’ultima misura disponibile. '
              'Non sono previsioni del livello futuro.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.width,
    this.detail,
  });
  final String label;
  final String value;
  final String? detail;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (detail != null)
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// Sintesi meteo di Sacile: condizione attuale e pioggia a 48 ore;
/// il tocco porta alla tab Meteo.
class HomeWeatherSummary extends ConsumerWidget {
  const HomeWeatherSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(sacileWeatherSummaryProvider);
    final result = state.valueOrNull;
    final data = result?.data;
    final now = DateTime.now();
    final end = now.add(const Duration(hours: 48));
    final hours = data?.hourly
        .where((h) => h.time.isAfter(now) && !h.time.isAfter(end))
        .toList();
    final sum = hours?.fold<double>(
      0,
      (total, hour) => total + hour.millimeters,
    );
    final rainText = data == null
        ? state.hasError
              ? 'Previsione momentaneamente non disponibile'
              : 'Caricamento della previsione…'
        : sum == null || hours!.length < 40
        ? 'Previsione a 48 ore incompleta'
        : sum < 0.1
        ? 'Nessuna pioggia prevista nelle prossime 48 ore'
        : '${NumberFormat('0.#', 'it').format(sum)} mm di pioggia nelle prossime 48 ore';
    final current = data?.current;
    final ui = current == null
        ? null
        : WeatherCodeUi.describe(current.weatherCode, isDay: current.isDay);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          onTap: () => ref.read(rootTabProvider.notifier).state = RootTab.meteo,
          leading: ui == null
              ? const Icon(Icons.umbrella_outlined)
              : Icon(ui.icon, size: 32, color: ui.color),
          title: Text(
            current == null
                ? 'Meteo a Sacile'
                : '${NumberFormat('0', 'it').format(current.temperature)}° · ${ui!.label}',
          ),
          subtitle: Text(
            '$rainText\n'
            'Open-Meteo · ${result?.fromCache == true ? 'dati salvati' : 'stima da modello'}'
            '${data == null ? '' : ' · ${_date.format(data.fetchedAtUtc.toLocal())}'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class HomeFavoriteStations extends ConsumerWidget {
  const HomeFavoriteStations({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites =
        ref.watch(favoriteStationsProvider).valueOrNull ?? <int>{};
    if (favorites.isEmpty) return const SizedBox.shrink();
    final state = ref.watch(basinProvider);
    final readings = state.valueOrNull?.data.readings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Le tue stazioni',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final station in basinStations.where(
              (s) => favorites.contains(s.id),
            ))
              Builder(
                builder: (context) {
                  final matches = readings?.where(
                    (r) => r.station.id == station.id,
                  );
                  final reading = matches == null || matches.isEmpty
                      ? null
                      : matches.first;
                  return ListTile(
                    title: Text(station.name),
                    subtitle: Text(
                      reading == null
                          ? state.isLoading
                                ? 'Caricamento…'
                                : 'Misura non disponibile'
                          : '${station.river} · ${_date.format(reading.timestampLocal)}',
                    ),
                    trailing: Text(
                      reading == null
                          ? '—'
                          : '${_meters.format(reading.value)} m',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StationDetailScreen(
                          station: station,
                          initialReading: reading,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
