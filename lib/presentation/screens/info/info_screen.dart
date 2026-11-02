import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';

/// Schermata informativa: scopo dell'app, avvisi, fonti e versione.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intestazione: nome app + tagline.
          Text(AppConfig.appName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            AppConfig.appTagline,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const _InfoSection(
            title: 'Scopo dell\'app',
            body:
                'Livenza Monitor è un servizio gratuito e senza pubblicità, '
                'al servizio della cittadinanza, per monitorare il livello '
                'del fiume Livenza a Sacile e nel suo bacino, con l\'obiettivo '
                'di informare in caso di piene.',
          ),
          const _InfoSection(
            title: 'Avviso importante',
            body:
                'Questo è un servizio NON ufficiale. I dati mostrati non sono '
                'validati e possono essere incompleti, ritardati o errati. '
                'In caso di emergenza fai riferimento esclusivamente alla '
                'Protezione Civile e chiama il numero unico di emergenza 112. '
                'Non utilizzare questa app come unica fonte per decisioni di '
                'sicurezza.',
          ),
          Text(
            'Fonti dei dati',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tocca una fonte per aprire il sito ufficiale.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          const _SourceLink(
            label:
                'Livelli idrometrici — Protezione Civile FVG, '
                'rete di monitoraggio',
            url: 'https://monitor.protezionecivile.fvg.it',
          ),
          const _SourceLink(
            label:
                'Allerte regionali — Centro Funzionale Decentrato, '
                'Protezione Civile FVG',
            url: 'https://cfd.protezionecivile.fvg.it',
          ),
          const _SourceLink(
            label: 'Protezione Civile della Regione FVG — sito ufficiale',
            url: 'https://www.protezionecivile.fvg.it',
          ),
          const _SourceLink(
            label:
                'Bollettino di previsione — ARPA FVG - OSMER e GRN '
                '(CC BY-SA 3.0 IT)',
            url: 'https://www.meteo.fvg.it',
          ),
          const _SourceLink(
            label:
                'Previsioni, scenari e serie storica — Open-Meteo / '
                'ERA5 Copernicus (CC BY 4.0)',
            url: 'https://open-meteo.com',
          ),
          const _SourceLink(
            label: 'Mappa — © OpenStreetMap contributors (ODbL)',
            url: 'https://www.openstreetmap.org/copyright',
          ),
          const _SourceLink(
            label: 'Servizio mappa — OpenStreetMap (senza chiave API)',
            url: 'https://operations.osmfoundation.org/policies/tiles/',
          ),
          const SizedBox(height: 6),
          Text(
            'Notizie: feed RSS delle rispettive testate (gli articoli '
            'si aprono sul sito della fonte).',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 20),
          const _InfoSection(
            title: 'Privacy',
            body:
                'L\'app non raccoglie, memorizza né trasmette alcun dato '
                'personale. Non ci sono account, tracciamenti, analytics o '
                'pubblicità. Le uniche connessioni sono quelle verso le '
                'fonti dati elencate sopra.',
          ),
          const _VersionSection(),
          const SizedBox(height: 4),
          // Testi delle licenze delle librerie incluse nel binario
          // (richiesto dalle licenze BSD/Apache delle dipendenze).
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Licenze open source'),
              subtitle: const Text('Librerie utilizzate dall\'app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Sezione "Versione": legge la versione reale dal pacchetto,
/// con fallback statico se il plugin non è disponibile.
class _VersionSection extends StatefulWidget {
  const _VersionSection();

  @override
  State<_VersionSection> createState() => _VersionSectionState();
}

class _VersionSectionState extends State<_VersionSection> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = info.version);
          }
        })
        .catchError((Object _) {
          // Plugin non disponibile (es. nei test): resta il fallback.
        });
  }

  @override
  Widget build(BuildContext context) {
    return _InfoSection(title: 'Versione', body: _version);
  }
}

/// Riga-fonte con link al sito ufficiale.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sezione riutilizzabile titolo + corpo testuale.
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}
