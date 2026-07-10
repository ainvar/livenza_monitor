import 'package:flutter/material.dart';

/// Stato dei dati mostrato dal banner in cima alle schermate.
enum BannerStatus {
  /// Caricamento in corso.
  loading,

  /// Dati aggiornati e recenti.
  fresh,

  /// Dati presenti ma vecchi (oltre la cache max age).
  stale,

  /// Nessuna connessione / dati non disponibili.
  offline,
}

/// Riga colorata che comunica lo stato di freschezza dei dati.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.status,
    required this.message,
  });

  final BannerStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ({Color color, IconData icon}) style = switch (status) {
      BannerStatus.loading => (
          color: const Color(0xFF546E7A), // grigio-blu
          icon: Icons.sync,
        ),
      BannerStatus.fresh => (
          color: const Color(0xFF2E7D32), // verde
          icon: Icons.check_circle,
        ),
      BannerStatus.stale => (
          color: const Color(0xFFEF6C00), // arancione
          icon: Icons.access_time,
        ),
      BannerStatus.offline => (
          color: const Color(0xFFC62828), // rosso
          icon: Icons.cloud_off,
        ),
    };

    return Container(
      width: double.infinity,
      color: style.color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(style.icon, size: 20, color: style.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: style.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
