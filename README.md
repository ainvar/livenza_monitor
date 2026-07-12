# Livenza Monitor 🌊

App civica, gratuita e senza pubblicità per monitorare il livello del fiume
**Livenza a Sacile (PN)** e nel suo bacino, con l'obiettivo di informare la
cittadinanza in caso di piene.

> **⚠️ AVVISO IMPORTANTE — LEGGERE PRIMA DELL'USO**
>
> Questo è un progetto amatoriale e **NON è un servizio ufficiale** di
> Protezione Civile, ARPA FVG, del Comune di Sacile o di qualsiasi altro
> ente pubblico. I dati mostrati **non sono validati** e possono essere
> incompleti, ritardati o errati.
>
> **In caso di emergenza fai riferimento esclusivamente ai canali ufficiali
> della Protezione Civile e chiama il Numero Unico di Emergenza 112.**
>
> Non utilizzare questa app come unica fonte per decisioni che riguardano
> la sicurezza di persone o cose.

## Funzionalità

- **Livenza** — livello idrometrico attuale a Sacile con stato di allerta,
  tendenza (salita/discesa/stabile) e grafico delle ultime 48 ore
- **Bacino** — mappa e livelli delle stazioni idrometriche del bacino del
  Livenza (Gorgazzo, Fiaschetti, Meschio, Noncello, Meduna…)
- **Meteo** — condizioni attuali e previsioni a 7 giorni per Sacile, con
  pioggia caduta nelle ultime 24 ore e prevista nelle prossime 48
- **Storico** — 86 anni di dati (dal 1940): pioggia annua, confronto
  dell'anno in corso con il clima, giorni record, temperature e
  riscaldamento climatico locale
- **Notizie** — notizie delle testate locali rilevanti per Sacile e il
  bacino del Livenza
- **Le grandi piene** — la memoria storica del fiume: gli eventi che hanno
  segnato il territorio, raccontati attraverso i dati

L'app funziona anche offline mostrando gli ultimi dati scaricati,
segnalandone chiaramente l'età.

### Soglie di allerta

Le soglie visualizzate per l'idrometro di Sacile (gialla da 5,50 m, rossa
da 6,00 m) sono **indicative** e inserite a scopo informativo: i livelli di
criticità ufficiali sono definiti e comunicati esclusivamente dalla
Protezione Civile.

## Fonti dei dati e attribuzioni

| Dato | Fonte | Licenza |
|---|---|---|
| Livelli idrometrici | [Protezione Civile FVG — rete di monitoraggio](https://monitor.protezionecivile.fvg.it/) | API pubblica della PA senza licenza esplicita; riuso non commerciale con attribuzione (art. 52 CAD), richiesta di conferma inviata all'ente |
| Bollettino di previsione | [ARPA FVG - OSMER e GRN](https://www.meteo.fvg.it/) | CC BY-SA 3.0 IT |
| Previsioni, scenari ensemble | [Open-Meteo](https://open-meteo.com/) | CC BY 4.0 |
| Serie storica 1940–oggi | Rianalisi ERA5 (Copernicus/ECMWF) via [Open-Meteo](https://open-meteo.com/) | CC BY 4.0 |
| Mappa (dati) | © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors | ODbL |
| Mappa (tile) | © [CARTO](https://carto.com/attributions) | Uso non commerciale con attribuzione |
| Notizie | Feed RSS delle rispettive testate (Il Friuli, Nordest24, Il Popolo) | © delle testate |

Note sui dati:

- I livelli idrometrici sono riferiti allo **zero idrometrico di ciascuna
  stazione** e non sono confrontabili tra stazioni diverse.
- La serie storica è una **rianalisi su griglia** (ERA5): valori ricostruiti
  per il punto di Sacile, non misure di una stazione meteorologica reale.
- Delle notizie vengono mostrati solo titolo, data e fonte; gli articoli si
  aprono sul sito della testata.

## Privacy

L'app non raccoglie, memorizza né trasmette alcun dato personale. Non ci
sono account, tracker, analytics o pubblicità. Le uniche connessioni sono
quelle verso le fonti dati elencate sopra.
Informativa completa: [PRIVACY.md](PRIVACY.md).

## Tecnologie

Flutter (Material 3) · Riverpod · fl_chart · flutter_map · architettura a
layer (datasource → cache → repository → provider) già predisposta per un
futuro backend con notifiche push.

## Compilare il progetto

```bash
flutter pub get
flutter run          # richiede un dispositivo/emulatore Android
```

Comandi utili:

```bash
flutter analyze                        # lint
flutter test                           # test unitari e widget
flutter test tool/generate_icons.dart  # rigenera le sorgenti dell'icona
dart run flutter_launcher_icons        # applica le icone launcher
flutter build apk --release            # APK di release
```

## Roadmap

- [ ] Release firmata
- [ ] Backend (Cloudflare Workers) e **notifiche push** al superamento delle soglie
- [ ] Notizie del Comune di Sacile
- [ ] Sezione "Le grandi piene": foto e ricordi d'epoca

## Licenza

Il **codice** è rilasciato sotto licenza [MIT](LICENSE).

I **dati** visualizzati appartengono ai rispettivi titolari e restano
soggetti alle loro licenze (vedi tabella sopra). Questo progetto non è
affiliato, approvato o sponsorizzato da alcuna delle fonti citate.
