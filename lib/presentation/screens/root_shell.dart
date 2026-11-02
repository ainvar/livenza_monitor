import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import 'basin/basin_screen.dart';
import 'home/home_screen.dart';
import 'info/info_screen.dart';
import 'news/news_screen.dart';
import 'weather/weather_screen.dart';

/// Contenitore principale con la NavigationBar Material 3.
///
/// Usa un [IndexedStack] così ogni schermata mantiene il proprio stato
/// (scroll, future, ecc.) quando si cambia tab; le tab non ancora
/// visitate non vengono costruite (niente richieste di rete inutili).
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  final Set<int> _visited = {RootTab.livenza};

  // Le schermate sono costruite una sola volta e preservate.
  static const List<Widget> _screens = [
    HomeScreen(),
    BasinScreen(),
    WeatherScreen(),
    NewsScreen(),
    InfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(rootTabProvider);
    _visited.add(index);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < _screens.length; i++)
            _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(rootTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_outlined),
            selectedIcon: Icon(Icons.water),
            label: 'Livenza',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Bacino',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Meteo',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'Notizie',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}
