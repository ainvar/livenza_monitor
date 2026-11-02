import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livenza_monitor/core/config/app_config.dart';
import 'package:livenza_monitor/presentation/providers/basin_providers.dart';

void main() {
  test(
    'il provider reale integra User-Agent e cache senza errori alla creazione della mappa',
    () async {
      // Una directory di test esplicita evita il plugin nativo e la rete.
      final cachePath = Directory('build/test-map-cache').absolute.path;
      final cache = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: cachePath,
        maxCacheSize: 50 * 1024 * 1024,
      );
      final container = ProviderContainer();
      final provider = container.read(mapTileProviderFactoryProvider)();
      try {
        expect(
          () => TileLayer(
            urlTemplate: AppConfig.mapTileUrl,
            userAgentPackageName: 'it.livenzamonitor.app',
            tileProvider: provider,
          ),
          returnsNormally,
        );
        expect(provider.headers['User-Agent'], AppConfig.mapUserAgent);
        expect((provider as NetworkTileProvider).cachingProvider, isNotNull);
      } finally {
        provider.dispose();
        container.dispose();
        await cache.destroy(deleteCache: true);
      }
    },
  );
}
