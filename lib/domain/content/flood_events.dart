/// Contenuti curati della sezione "Le grandi piene del Livenza".
///
/// I dati di pioggia citati provengono dalla serie storica ERA5
/// (1940→oggi) per il punto di Sacile, la stessa della sezione Storico:
/// sono ricostruzioni su griglia, non misure di stazione.
library;

/// Evento storico di piena o pioggia eccezionale.
class FloodEvent {
  const FloodEvent({
    required this.year,
    required this.month,
    required this.day,
    this.endMonth,
    this.endDay,
    required this.dateLabel,
    required this.title,
    required this.rainFact,
    required this.story,
  });

  final int year;
  final int month;
  final int day;
  final int? endMonth;
  final int? endDay;

  DateTime get startDate => DateTime(year, month, day);
  DateTime get endDate => DateTime(year, endMonth ?? month, endDay ?? day);

  /// Ricorrenza di un giorno compreso nel periodo dell'evento.
  bool isAnniversaryOn(DateTime date) {
    if (date.year <= year) return false;
    final anniversary = DateTime(year, date.month, date.day);
    return !anniversary.isBefore(startDate) && !anniversary.isAfter(endDate);
  }

  String get shareText =>
      'Livenza Monitor · La memoria del fiume\n'
      '$dateLabel — $title\n\n$rainFact\n\n$story\n\n'
      'Piogge da rianalisi ERA5 sul punto di Sacile: '
      'ricostruzioni su griglia, non misure di stazione.';

  /// Data leggibile (es. "4 novembre 1966").
  final String dateLabel;

  final String title;

  /// Il dato di pioggia, dalla nostra serie storica.
  final String rainFact;

  /// Racconto breve dell'evento.
  final String story;
}

/// Eventi in ordine cronologico inverso (dal più recente).
const floodEvents = <FloodEvent>[
  FloodEvent(
    year: 2024,
    month: 5,
    day: 16,
    dateLabel: '16 maggio 2024',
    title: 'La piena di primavera',
    rainFact: '106 mm in un giorno, 134 mm in tre giorni',
    story:
        'Un maggio fuori stagione: una perturbazione intensa porta in '
        'poche ore una pioggia da record autunnale. Il Livenza e il '
        'Meschio si gonfiano rapidamente, con allagamenti e disagi tra '
        'Sacile e Caneva. È il terzo giorno più piovoso degli ultimi '
        'vent\'anni nella serie storica.',
  ),
  FloodEvent(
    year: 2019,
    month: 11,
    day: 12,
    endDay: 18,
    dateLabel: '12–18 novembre 2019',
    title: 'La settimana delle piene ripetute',
    rainFact:
        '287 mm in sette giorni, con due giorni oltre i 100 mm '
        '(15 e 17 novembre)',
    story:
        'Un autunno che non dà tregua: le perturbazioni si susseguono '
        'a distanza di ore e il bacino non fa in tempo a smaltire. Il '
        'Livenza resta sopra i livelli di guardia per giorni, mentre '
        'l\'acqua alta record flagella Venezia. Nella classifica dei '
        'giorni più piovosi dal 1940, tre date di quel novembre entrano '
        'nella top 10.',
  ),
  FloodEvent(
    year: 2010,
    month: 10,
    day: 31,
    endMonth: 11,
    endDay: 2,
    dateLabel: '31 ottobre – 2 novembre 2010',
    title: 'L\'alluvione di Ognissanti',
    rainFact: '148 mm in tre giorni',
    story:
        'Piogge persistenti su pianura e Prealpi mandano in crisi '
        'mezzo Nordest: il Veneto vive una delle sue alluvioni più '
        'gravi, e anche il bacino del Livenza va in piena. A dicembre '
        'dello stesso anno un\'altra ondata (140 mm attorno a Natale) '
        'chiude un 2010 tra i più piovosi della serie.',
  ),
  FloodEvent(
    year: 2002,
    month: 11,
    day: 23,
    endDay: 27,
    dateLabel: '23–27 novembre 2002',
    title: 'La piena di fine novembre',
    rainFact: '170 mm in cinque giorni',
    story:
        'Giorni di pioggia insistente saturano il terreno e portano '
        'il Livenza ai livelli di guardia. È uno degli eventi di '
        'riferimento dell\'epoca recente per la bassa pianura tra '
        'Sacile, Brugnera e Prata, dove il fiume mostra il suo '
        'carattere lento ma ostinato: sale piano, e piano se ne va.',
  ),
  FloodEvent(
    year: 1976,
    month: 10,
    day: 30,
    dateLabel: '30 ottobre 1976',
    title: 'Il diluvio d\'ottobre',
    rainFact: '126 mm in un giorno, terzo valore dell\'intera serie',
    story:
        'In sole ventiquattro ore cade quasi un decimo della pioggia '
        'di un anno intero. Un evento rimasto a lungo il terzo giorno '
        'più piovoso mai ricostruito per Sacile, dietro soltanto ai '
        'giganti del 1966 e del 1965.',
  ),
  FloodEvent(
    year: 1966,
    month: 11,
    day: 4,
    dateLabel: '4 novembre 1966',
    title: 'La Grande Alluvione',
    rainFact:
        '199 mm in un giorno — il record assoluto dal 1940 — '
        'e 249 mm in tre giorni',
    story:
        'La stessa immensa perturbazione che sommerge Firenze e '
        'porta a Venezia l\'acqua alta più alta della sua storia si '
        'abbatte anche sul bacino del Livenza. È il giorno più piovoso '
        'dell\'intera serie storica di Sacile: fiumi in piena in tutto '
        'il Triveneto, argini in crisi, paesi allagati. Il 4 novembre '
        '1966 resta il metro con cui si misurano tutte le piene '
        'venute dopo.',
  ),
  FloodEvent(
    year: 1965,
    month: 9,
    day: 2,
    dateLabel: '2 settembre 1965',
    title: 'Il nubifragio di fine estate',
    rainFact: '165 mm in un giorno, 287 mm in quattro giorni',
    story:
        'A cavallo tra agosto e settembre un vortice di piogge '
        'torrenziali scarica sul bacino quasi trecento millimetri in '
        'quattro giorni: il secondo giorno più piovoso della serie. '
        'Un anno dopo sarebbe arrivata l\'alluvione del 1966, ma per '
        'chi visse quell\'estate il Livenza aveva già dato un '
        'avvertimento.',
  ),
];
