import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/threshold_colors.dart';
import '../../data/models/regional_alert.dart';
import '../../domain/services/regional_alert_selector.dart';
import '../providers/alert_providers.dart';

final _dayTimeFormat = DateFormat('EEE d MMM HH:mm', 'it');

/// Colore e nome del livello di allerta regionale.
(Color, String) regionalAlertStyle(int level) => switch (level) {
      >= 3 => (ThresholdColors.soglia3, 'ROSSA'),
      2 => (ThresholdColors.soglia2, 'ARANCIONE'),
      _ => (ThresholdColors.soglia1, 'GIALLA'),
    };

/// Card mostrata in Home quando il CFD ha emesso un'allerta che
/// interessa la zona di Sacile (in corso o imminente). In tutti gli
/// altri casi non occupa spazio.
class RegionalAlertCard extends ConsumerWidget {
  const RegionalAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(regionalAlertProvider).valueOrNull;
    if (result == null) return const SizedBox.shrink();

    final alert = const RegionalAlertSelector()
        .select(result.alerts, nowUtc: DateTime.now().toUtc());
    if (alert == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final (color, levelName) = regionalAlertStyle(alert.level);
    final nowUtc = DateTime.now().toUtc();
    final validity = alert.isActiveAt(nowUtc)
        ? 'In corso fino alle ${_dayTimeFormat.format(alert.toUtc.toLocal())}'
        : 'Dalle ${_dayTimeFormat.format(alert.fromUtc.toLocal())} '
            'alle ${_dayTimeFormat.format(alert.toUtc.toLocal())}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color, width: 1.5),
        ),
        color: color.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(context, alert),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALLERTA $levelName — n. ${alert.number}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (alert.phenomena.isNotEmpty)
                        Text(
                          _capitalize(alert.phenomena.join(' · ')),
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        validity,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'CFD Protezione Civile FVG · tocca per i dettagli',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, RegionalAlert alert) {
    final (color, levelName) = regionalAlertStyle(alert.level);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              Text(
                'Allerta $levelName regionale n. ${alert.number}',
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Text(
                'Zona di Sacile (FVG-A) · emessa il '
                '${_dayTimeFormat.format(alert.emittedUtc.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (alert.situation.isNotEmpty)
                _DetailSection(title: 'Situazione', body: alert.situation),
              if (alert.forecast.isNotEmpty)
                _DetailSection(
                  title: 'Previsione meteo',
                  body: alert.forecast,
                ),
              if (alert.assessment.isNotEmpty)
                _DetailSection(
                  title: 'Possibili effetti',
                  body: alert.assessment,
                ),
              if (alert.operationalStage.isNotEmpty)
                _DetailSection(
                  title: 'Fase operativa',
                  body: alert.operationalStage,
                ),
              const SizedBox(height: 16),
              if (alert.documentUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(alert.documentUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Documento ufficiale (PDF)'),
                ),
              const SizedBox(height: 8),
              Text(
                'Fonte: Centro Funzionale Decentrato — Protezione Civile '
                'della Regione FVG. In emergenza chiama il 112.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
