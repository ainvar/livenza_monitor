import 'package:flutter/material.dart';

/// Stato individuale: una stazione aggiornata non nasconde quelle ferme.
class StationFreshness extends StatelessWidget {
  const StationFreshness({super.key, required this.timestampUtc});

  final DateTime? timestampUtc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = timestampUtc == null
        ? null
        : DateTime.now().toUtc().difference(timestampUtc!);
    final unexpected = age != null && age < const Duration(minutes: -10);
    final stale =
        age == null || age > const Duration(minutes: 90) || unexpected;
    final label = switch (age) {
      null => 'Misura non disponibile',
      _ when unexpected => 'Orario da verificare',
      _ when age.inMinutes < 1 => 'Misura appena aggiornata',
      _ when age.inMinutes < 60 => 'Misura di ${age.inMinutes} min fa',
      _ when age.inHours < 24 => 'Misura di ${age.inHours} h fa',
      _ => 'Misura di ${age.inDays} giorni fa',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          stale ? Icons.info_outline : Icons.schedule,
          size: 14,
          color: stale
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            stale && age != null && !unexpected
                ? '$label · dato datato'
                : label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: stale
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
