import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/basin_reading.dart';
import '../../../data/models/basin_station.dart';
import '../../../data/repositories/basin_repository.dart';
import '../../../domain/services/alert_service.dart';
import '../../providers/basin_providers.dart';
import '../../providers/favorite_stations_provider.dart';
import '../../providers/level_providers.dart';
import '../../widgets/data_status_banner.dart';
import '../../widgets/error_body.dart';
import '../../widgets/favorite_station_button.dart';
import '../../widgets/station_freshness.dart';
import 'station_detail_screen.dart';

final _meterFormat = NumberFormat('0.00', 'it');
final _dayTimeFormat = DateFormat('dd/MM HH:mm');

class BasinScreen extends ConsumerWidget {
  const BasinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(basinProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bacino'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () => ref.read(basinProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          dataStatusBanner<BasinResult>(
            state: state,
            fetchedAtUtc: (r) => r.data.fetchedAtUtc,
            newestMeasureUtc: (r) => r.data.newestMeasureUtc,
            fromCache: (r) => r.fromCache,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(basinProvider.notifier).refresh(),
              child: switch (state) {
                AsyncValue(:final value?) => _BasinBody(result: value),
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

class _BasinBody extends ConsumerWidget {
  const _BasinBody({required this.result});
  final BasinResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readings = {for (final r in result.data.readings) r.station.id: r};
    final favoritesState = ref.watch(favoriteStationsProvider);
    final favorites = favoritesState.valueOrNull ?? <int>{};
    final preferred = basinStations.where((s) => favorites.contains(s.id));
    final others = basinStations.where((s) => !favorites.contains(s.id));
    final missing = basinStations.length - readings.length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (preferred.isNotEmpty) ...[
          Text('Le tue stazioni', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final station in preferred)
            _StationTile(station: station, reading: readings[station.id]),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(height: 280, child: _BasinMap(readings: readings)),
        ),
        const SizedBox(height: 16),
        Text('Stazioni da monte a valle', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tocca una stazione per esplorare le ultime 48 ore. '
          'La stella la aggiunge ai preferiti su questo dispositivo.',
          style: theme.textTheme.bodySmall,
        ),
        if (favoritesState.hasError)
          TextButton.icon(
            onPressed: () => ref.invalidate(favoriteStationsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova a caricare i preferiti'),
          ),
        if (missing > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$missing ${missing == 1 ? 'stazione senza misura' : 'stazioni senza misura'} '
            'nell’ultimo aggiornamento.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final station in others)
          _StationTile(station: station, reading: readings[station.id]),
        const SizedBox(height: 8),
        Text(
          'I livelli sono riferiti allo zero idrometrico di ciascuna '
          'stazione e non sono confrontabili tra loro. '
          'Le soglie indicative sono impostate solo per Sacile.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

void _openStation(
  BuildContext context,
  BasinStation station,
  BasinReading? reading,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          StationDetailScreen(station: station, initialReading: reading),
    ),
  );
}

class _BasinMap extends ConsumerWidget {
  const _BasinMap({required this.readings});
  final Map<int, BasinReading> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alertService = ref.watch(alertServiceProvider);
    return FlutterMap(
      options: MapOptions(
        maxZoom: 19,
        initialCameraFit: CameraFit.coordinates(
          coordinates: [for (final s in basinStations) LatLng(s.lat, s.lon)],
          padding: const EdgeInsets.all(36),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: 'it.livenzamonitor.app',
          tileProvider: ref.watch(mapTileProviderFactoryProvider)(),
          maxNativeZoom: 19,
          panBuffer: 0,
        ),
        MarkerLayer(
          markers: [
            for (final station in basinStations)
              Marker(
                point: LatLng(station.lat, station.lon),
                width: 76,
                height: 48,
                child: _StationMarker(
                  station: station,
                  reading: readings[station.id],
                  color: readings[station.id] == null
                      ? theme.colorScheme.outline
                      : station.isReference
                      ? alertService.classify(readings[station.id]!.value).color
                      : theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({
    required this.station,
    required this.reading,
    required this.color,
  });
  final BasinStation station;
  final BasinReading? reading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = reading == null
        ? '—'
        : '${_meterFormat.format(reading!.value)} m';
    return Semantics(
      button: true,
      label:
          '${station.name}, ${station.river}: ${reading == null ? 'misura non disponibile' : text}. Apri storico.',
      child: Tooltip(
        message: '${station.name} · ${station.river}',
        child: InkWell(
          onTap: () => _openStation(context, station, reading),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black26),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StationTile extends ConsumerWidget {
  const _StationTile({required this.station, required this.reading});
  final BasinStation station;
  final BasinReading? reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = station.isReference && reading != null
        ? ref.watch(alertServiceProvider).classify(reading!.value).color
        : theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStation(context, station, reading),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name, style: theme.textTheme.titleSmall),
                    Text(station.river, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    StationFreshness(timestampUtc: reading?.timestampUtc),
                    if (reading != null)
                      Text(
                        _dayTimeFormat.format(reading!.timestampLocal),
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reading == null
                    ? '—'
                    : '${_meterFormat.format(reading!.value)} m',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              FavoriteStationButton(station: station),
            ],
          ),
        ),
      ),
    );
  }
}
