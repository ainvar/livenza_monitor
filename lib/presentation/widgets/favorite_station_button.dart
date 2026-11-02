import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/basin_station.dart';
import '../providers/favorite_stations_provider.dart';

class FavoriteStationButton extends ConsumerWidget {
  const FavoriteStationButton({super.key, required this.station});

  final BasinStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteStationsProvider);
    final selected = state.valueOrNull?.contains(station.id) ?? false;
    final label = selected
        ? 'Rimuovi ${station.name} (${station.river}) dai preferiti'
        : 'Aggiungi ${station.name} (${station.river}) ai preferiti';
    return IconButton(
      tooltip: label,
      isSelected: selected,
      icon: const Icon(Icons.star_border_rounded),
      selectedIcon: const Icon(Icons.star_rounded),
      onPressed: state.hasValue
          ? () async {
              try {
                await ref
                    .read(favoriteStationsProvider.notifier)
                    .toggle(station.id);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impossibile salvare i preferiti. Riprova.'),
                  ),
                );
              }
            }
          : null,
    );
  }
}
