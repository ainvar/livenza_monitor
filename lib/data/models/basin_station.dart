/// Stazione idrometrica del bacino del Livenza.
class BasinStation {
  const BasinStation({
    required this.id,
    required this.name,
    required this.river,
    required this.lat,
    required this.lon,
    this.isReference = false,
  });

  /// Id stazione sull'API monitor della Protezione Civile FVG.
  final int id;

  final String name;

  /// Corso d'acqua su cui si trova la stazione.
  final String river;

  final double lat;
  final double lon;

  /// True per la stazione di riferimento dell'app (Sacile),
  /// l'unica per cui sono note le soglie di allerta.
  final bool isReference;
}

/// Stazioni curate del bacino del Livenza, da monte verso valle.
///
/// Sottoinsieme della rete PC FVG: solo idrometri fluviali del bacino
/// (esclusi invasi e stazioni di altri bacini, es. Tagliamento).
const basinStations = <BasinStation>[
  BasinStation(
    id: 587,
    name: 'Gorgazzo (Polcenigo)',
    river: 'Gorgazzo',
    lat: 46.0387,
    lon: 12.4966,
  ),
  BasinStation(
    id: 58,
    name: 'Fiaschetti (Caneva)',
    river: 'Livenza',
    lat: 45.9853,
    lon: 12.4833,
  ),
  BasinStation(
    id: 121,
    name: 'Ponte della Muda',
    river: 'Meschio',
    lat: 45.9461,
    lon: 12.4393,
  ),
  BasinStation(
    id: 543,
    name: 'Sacile',
    river: 'Livenza',
    lat: 45.9509,
    lon: 12.5022,
    isReference: true,
  ),
  BasinStation(
    id: 155,
    name: 'San Cassiano (Brugnera)',
    river: 'Livenza',
    lat: 45.8768,
    lon: 12.5351,
  ),
  BasinStation(
    id: 132,
    name: 'Pordenone',
    river: 'Noncello',
    lat: 45.9518,
    lon: 12.6590,
  ),
  BasinStation(
    id: 130,
    name: 'Pordenone',
    river: 'Meduna',
    lat: 45.9460,
    lon: 12.6992,
  ),
  BasinStation(
    id: 579,
    name: 'Ponte di Corva',
    river: 'Meduna',
    lat: 45.9168,
    lon: 12.6602,
  ),
  BasinStation(
    id: 137,
    name: 'Prata di Pordenone',
    river: 'Meduna',
    lat: 45.8985,
    lon: 12.6036,
  ),
  BasinStation(
    id: 188,
    name: 'Tremeacque',
    river: 'Meduna',
    lat: 45.8282,
    lon: 12.5704,
  ),
  BasinStation(
    id: 187,
    name: 'Tremeacque',
    river: 'Livenza',
    lat: 45.8284,
    lon: 12.5686,
  ),
  BasinStation(
    id: 106,
    name: 'Panigai (Pravisdomini)',
    river: 'Livenza',
    lat: 45.8294,
    lon: 12.6756,
  ),
];
