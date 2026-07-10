import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/news_item.dart';
import '../../../data/repositories/news_repository.dart';
import '../../providers/news_providers.dart';
import '../../widgets/data_status_banner.dart';
import '../../widgets/error_body.dart';

final _dayTimeFormat = DateFormat('dd/MM HH:mm');

/// Notizie locali rilevanti per Sacile e il bacino del Livenza,
/// aggregate dai feed RSS delle testate del territorio.
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notizie'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () => ref.read(newsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          dataStatusBanner<NewsResult>(
            state: state,
            fetchedAtUtc: (r) => r.fetchedAtUtc,
            newestMeasureUtc: (r) => r.fetchedAtUtc,
            fromCache: (r) => r.fromCache,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(newsProvider.notifier).refresh(),
              child: switch (state) {
                AsyncValue(:final value?) => _NewsBody(result: value),
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

class _NewsBody extends StatelessWidget {
  const _NewsBody({required this.result});

  final NewsResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = result.items;

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.newspaper,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessuna notizia locale al momento',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Qui compaiono le notizie delle testate locali che '
                  'riguardano Sacile, il Livenza e il suo bacino.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in items) _NewsTile(item: item),
        const SizedBox(height: 8),
        Text(
          'Titoli e contenuti appartengono alle rispettive testate; '
          'gli articoli si aprono sul sito della fonte.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => launchUrl(
          Uri.parse(item.link),
          mode: LaunchMode.externalApplication,
        ),
        title: Text(
          item.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${item.source} · '
            '${_dayTimeFormat.format(item.publishedLocal)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
      ),
    );
  }
}
