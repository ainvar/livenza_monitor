/// Singola misura idrometrica (livello in metri a un istante).
class HydroMeasure {
  const HydroMeasure({required this.timestampUtc, required this.value});

  /// Istante della misura, in UTC (l'API restituisce `dt` in UTC).
  final DateTime timestampUtc;

  /// Livello idrometrico in metri.
  final double value;

  DateTime get timestampLocal => timestampUtc.toLocal();

  /// Parsa una misura dal payload dell'API monitor
  /// (`{"dt": "2026-07-02 15:30:00", "value": 2.69}`).
  /// Restituisce null se il valore è assente o non numerico.
  static HydroMeasure? fromApiJson(Map<String, dynamic> json) {
    final dt = json['dt'];
    final value = json['value'];
    if (dt is! String || value is! num) return null;
    final parsed = DateTime.tryParse('${dt.replaceFirst(' ', 'T')}Z');
    if (parsed == null) return null;
    return HydroMeasure(timestampUtc: parsed, value: value.toDouble());
  }

  /// Serializzazione compatta per la cache locale.
  Map<String, dynamic> toCacheJson() => {
        't': timestampUtc.toIso8601String(),
        'v': value,
      };

  static HydroMeasure? fromCacheJson(Map<String, dynamic> json) {
    final t = json['t'];
    final v = json['v'];
    if (t is! String || v is! num) return null;
    final parsed = DateTime.tryParse(t);
    if (parsed == null) return null;
    return HydroMeasure(timestampUtc: parsed.toUtc(), value: v.toDouble());
  }
}
