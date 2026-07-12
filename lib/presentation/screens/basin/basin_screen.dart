import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/basin_reading.dart';
import '../../../data/repositories/basin_repository.dart';
import '../../../domain/services/alert_service.dart';
import '../../providers/basin_providers.dart';
import '../../providers/level_providers.dart';
import '../../widgets/data_status_banner.dart';
import '../../widgets/error_body.dart';

final _meterFormat = NumberFormat('0.00', 'it');
final _dayTimeFormat = DateFormat('dd/MM HH:mm');

/// Schermata del bacino: mappa e ultime letture degli idrometri
/// del bacino del Livenza (da monte a valle).
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
    final readings = result.data.readings;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 300,
            child: _BasinMap(readings: readings),
          ),
        ),
        const SizedBox(height: 12),
        for (final reading in readings) _StationTile(reading: reading),
        const SizedBox(height: 8),
        Text(
          'I livelli sono riferiti allo zero idrometrico di ciascuna '
          'stazione e non sono confrontabili tra loro. '
          'Le soglie di allerta sono note solo per Sacile.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Mappa OpenStreetMap con i marker delle stazioni.
class _BasinMap extends ConsumerWidget {
  const _BasinMap({required this.readings});

  final List<BasinReading> readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertService = ref.watch(alertServiceProvider);

    final points = [
      for (final r in readings) LatLng(r.station.lat, r.station.lon),
    ];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length >= 2
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(36),
              )
            : const CameraFit.coordinates(
                coordinates: [LatLng(45.95, 12.55)],
              ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          subdomains: AppConfig.mapTileSubdomains,
          userAgentPackageName: 'it.livenzamonitor.livenza_monitor',
          tileProvider: ref.watch(mapTileProviderFactoryProvider)(),
        ),
        MarkerLayer(
          markers: [
            for (final r in readings)
              Marker(
                point: LatLng(r.station.lat, r.station.lon),
                width: 66,
                height: 30,
                child: _MarkerPill(
                  reading: r,
                  color: r.station.isReference
                      ? alertService.classify(r.value).color
                      : Theme.of(context).colorScheme.primary,
                  onTap: () => _showStationSheet(context, r, alertService),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            TextSourceAttribution(
              '© CARTO',
              onTap: () => launchUrl(
                Uri.parse('https://carto.com/attributions'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Etichetta a pillola con il livello, usata come marker sulla mappa.
class _MarkerPill extends StatelessWidget {
  const _MarkerPill({
    required this.reading,
    required this.color,
    required this.onTap,
  });

  final BasinReading reading;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(blurRadius: 4, color: Colors.black26),
          ],
        ),
        child: Text(
          '${_meterFormat.format(reading.value)} m',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Riga di elenco per una stazione.
class _StationTile extends ConsumerWidget {
  const _StationTile({required this.reading});

  final BasinReading reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alertService = ref.watch(alertServiceProvider);
    final station = reading.station;
    final isReference = station.isReference;
    final color = isReference
        ? alertService.classify(reading.value).color
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showStationSheet(context, reading, alertService),
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(
          station.name,
          style: isReference
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        ),
        subtitle: Text(
          '${station.river} · ${_dayTimeFormat.format(reading.timestampLocal)}',
        ),
        trailing: Text(
          '${_meterFormat.format(reading.value)} m',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Dettaglio stazione in bottom sheet.
void _showStationSheet(
  BuildContext context,
  BasinReading reading,
  AlertService alertService,
) {
  final station = reading.station;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final alert = station.isReference
          ? alertService.classify(reading.value)
          : null;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(station.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Corso d\'acqua: ${station.river}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_meterFormat.format(reading.value)} m',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: alert?.color ?? theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'misura delle '
                    '${_dayTimeFormat.format(reading.timestampLocal)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (alert != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            ],
          ],
        ),
      );
    },
  );
}

