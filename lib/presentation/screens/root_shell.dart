import 'package:flutter/material.dart';

import 'basin/basin_screen.dart';
import 'home/home_screen.dart';
import 'info/info_screen.dart';
import 'news/news_screen.dart';
import 'weather/weather_screen.dart';

/// Contenitore principale con la NavigationBar Material 3.
///
/// Usa un [IndexedStack] così ogni schermata mantiene il proprio stato
/// (scroll, future, ecc.) quando si cambia tab.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

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
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
