import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/content/flood_events.dart';
import '../weather/history_screen.dart';

/// Sezione "amarcord": le grandi piene del Livenza raccontate
/// attraverso i dati della serie storica.
class AmarcordScreen extends StatelessWidget {
  const AmarcordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final anniversaries = floodEvents
        .where((event) => event.isAnniversaryOn(today))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Le grandi piene')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('La memoria del fiume', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Gli eventi che hanno segnato la storia recente del Livenza, '
            'raccontati attraverso i dati della serie storica 1940–oggi '
            '(rianalisi ERA5, punto di Sacile).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tocca un evento per leggerne il racconto e condividerlo.',
            style: theme.textTheme.bodySmall,
          ),
          if (anniversaries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accadde oggi',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    for (final event in anniversaries)
                      Text(
                        '${event.year} · ${event.title}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final event in floodEvents)
            _EventCard(
              event: event,
              initiallyExpanded:
                  event == floodEvents.first || event.isAnniversaryOn(today),
            ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Come leggere questi eventi',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Le piogge riportate sono ricostruzioni ERA5 sul '
                          'punto di Sacile, non misure di un pluviometro né '
                          'medie dell’intero bacino. Il racconto non '
                          'ricostruisce i livelli del fiume.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: const Text('Esplora la serie storica'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.initiallyExpanded});

  final FloodEvent event;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(event.startDate),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.dateLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(event.title, style: theme.textTheme.titleMedium),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    event.rainFact,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.story,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () {
                final box = buttonContext.findRenderObject() as RenderBox?;
                Share.share(
                  event.shareText,
                  subject: '${event.title} · ${event.dateLabel}',
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Condividi il racconto'),
            ),
          ),
        ],
      ),
    );
  }
}
