import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
          const _InfoSection(
            title: 'Fonti dei dati',
            body:
                'Dati idrometrici: Protezione Civile FVG / ARPA FVG — OSMER.\n'
                'Previsioni meteo: Open-Meteo.\n'
                'Mappa: © OpenStreetMap contributors.\n'
                'Licenza dati: Creative Commons Attribuzione 3.0 Italia '
                '(CC BY 3.0 IT).',
          ),
          const _VersionSection(),
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
  String _version = '0.1.0 (sviluppo)';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (sviluppo)');
      }
    }).catchError((Object _) {
      // Plugin non disponibile (es. nei test): resta il fallback.
    });
  }

  @override
  Widget build(BuildContext context) {
    return _InfoSection(title: 'Versione', body: _version);
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
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
