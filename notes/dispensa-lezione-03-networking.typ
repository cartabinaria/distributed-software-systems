#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 03",
  subtitle: "Networking per i Sistemi Distribuiti, QoS e Protocolli",
  accent-color: rgb("#1a9133")
)

= 1. L'Illusione della Chiamata Locale

Un sistema distribuito consiste in software che viene eseguito su più macchine collegate da una rete, con l'obiettivo di apparire all'utente come un singolo sistema coerente.

#callout(title: "Rottura dell'Astrazione Monolitica", kind: "warning")[
Una chiamata di rete *NON è una chiamata a una funzione locale*.
In locale, l'invocazione di una procedura impiega nanosecondi e possiede una semantica di esecuzione a guasto totale (all-or-nothing). In rete, ogni freccia di comunicazione può fallire o subire ritardi significativi. Il software distribuito deve gestire esplicitamente l'incertezza, i timeout, i retry e le risposte tardive.
]


= 2. Le 8 Fallacie della Computazione Distribuita (Deutsch)

Quando si progettano applicazioni distribuite per la prima volta, si tende a fare otto assunzioni errate (*fallacie*) sulla rete:

1. *La rete è affidabile* ($->$ Falso): Perdite di pacchetti e disconnessioni sono eventi ordinari.
2. *La latenza è zero* ($->$ Falso): Il tempo di trasferimento tra nodi è sempre positivo e significativo.
3. *La banda è infinita* ($->$ Falso): Il payload dei messaggi impatta direttamente sulle prestazioni.
4. *La rete è sicura* ($->$ Falso): I dati in transito possono essere intercettati, alterati o bloccati.
5. *La topologia non cambia* ($->$ Falso): Nodi, IP e rotte cambiano dinamicamente.
6. *C'è un solo amministratore* ($->$ Falso): I sistemi attraversano domini amministrativi eterogenei.
7. *Il costo di trasporto è zero* ($->$ Falso): L'infrastruttura di rete comporta costi operativi ed economici.
8. *La rete è omogenea* ($->$ Falso): Dispositivi, architetture hardware e sistemi operativi sono eterogenei.


= 3. Parametri di Prestazione della Rete e QoS

La qualità del servizio (*Quality of Service - QoS*) della rete è caratterizzata da quattro parametri fondamentali:

#table(
  columns: (1.5fr, 1.2fr, 2.3fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Parametro QoS* ], [ *Unità di Misura* ], [ *Significato e Impatto Architetturale* ],
  [ *Bandwidth (Banda)* ], [ bit/s, Mbps, Gbps ], [ Quantità massima di dati trasferibile nell'unità di tempo attraverso il canale. ],
  [ *Latency (Latenza)* ], [ millisecondi (ms) ], [ Ritardo fisso che intercorre prima che i dati inizino ad arrivare al destinatario. ],
  [ *Packet Loss* ], [ percentuale (%) ], [ Quota di pacchetti scartati dai router causa congestione o errori di canale. ],
  [ *Jitter* ], [ millisecondi (ms) ], [ Variabilità del ritardo tra pacchetti consecutivi; critica per flussi real-time. ]
)

== 3.1 La Formula del Tempo di Trasmissione Totale

$$ text("Tempo di Trasmissione Totale") = text("Latenza di Rete") + frac(text("Dimensione del Messaggio (bit)"), text("Banda di Rete (bit/s)")) $$

#callout(title: "Latency Budget e Regola d'Oro di Programmazione", kind: "definition")[
Poiché la latenza di rete introduce ritardi dell'ordine dei millisecondi ($10^4 - 10^6$ volte più lenti dell'accesso in RAM locale), la regola d'oro nella progettazione distribuita è:
*Minimizzare i round-trip remoti prima di ottimizzare il calcolo locale.*
Risparmiare una singola chiamata di rete evita centinaia di millisecondi di attesa, un guadagno immensamente superiore all'ottimizzazione di cicli CPU.
]


= 4. Modelli di Protocollo a Stratificazione

Per gestire la complessità della comunicazione, le architetture di rete si organizzano secondo modelli a strati basati sull'incapsulamento dei dati.

== 4.1 Modello OSI vs Modello TCP/IP

#table(
  columns: (1.2fr, 1.5fr, 2.3fr),
  fill: (x, y) => if y == 0 { rgb("#f0fdf4") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Livello OSI (7 Livelli)* ], [ *Livello TCP/IP (4 Livelli)* ], [ *Esempi e Responsabilità* ],
  [ Applicazione, Presentazione, Sessione ], [ *Application Layer* ], [ HTTP, HTTPS, DNS, gRPC, SSH, FTP. Logica applicativa e formati. ],
  [ Trasporto ], [ *Transport Layer* ], [ TCP, UDP. Comunicazione process-to-process e gestione porte. ],
  [ Rete ], [ *Internetwork Layer* ], [ IP (IPv4, IPv6), ICMP. Indirizzamento logico e routing host-to-host. ],
  [ Data Link, Fisico ], [ *Network Interface Layer* ], [ Ethernet, Wi-Fi (802.11), Fiber. Trasmissione del segnale fisico. ]
)

== 4.2 Incapsulamento dei Dati
Man mano che i dati scendono lungo la pila dei protocolli del mittente, ogni livello aggiunge una propria intestazione (*header*):
$$ text("Dati Applicativi") -> text("Segmento TCP") -> text("Pacchetto IP") -> text("Frame Ethernet") $$
Al destinatario, il processo inverso (*decapsulamento*) rimuove sequenzialmente gli header per consegnare il payload originale all'applicazione.


= 5. Meccanismi di Commutazione dei Pacchetti

1. *Datagram Delivery (Packet Switching)*:
  - Ogni pacchetto viene instradato in modo del tutto indipendente dagli altri (*one-shot*).
  - Non richiede alcuna fase di setup preventivo della connessione.
  - I pacchetti sequenziali possono seguire percorsi diversi e arrivare *fuori ordine* al destinatario (es. IP, UDP).
2. *Virtual Circuit Delivery*:
  - Viene instaurato un percorso fisso (circuito virtuale) tra sorgente e destinazione prima dell'invio dei dati.
  - I pacchetti seguono la medesima rotta e mantengono rigorosamente l'ordine d'arrivo.


= 6. Confronto tra Protocolli di Trasporto: TCP vs UDP

#table(
  columns: (1.5fr, 2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Caratteristica* ], [ *TCP (Transmission Control Protocol)* ], [ *UDP (User Datagram Protocol)* ],
  [ *Connessione* ], [ Orientato alla connessione (3-Way Handshake) ], [ Connectionless (Nessun handshake) ],
  [ *Affidabilità* ], [ Consegna garantita, ordinata ed esente da errori ], [ Nessuna garanzia di consegna o ordinamento ],
  [ *Controllo Flusso/Congestione* ], [ Presente (sliding window, slow start) ], [ Assente ],
  [ *Overhead & Latenza* ], [ Maggiore overhead di header e latenza per RTT ], [ Overhead minimo, latenza ultra-bassa ],
  [ *Casi d'Uso Elettivi* ], [ Web (HTTP/1.1-2), Trasferimento File, Email, gRPC ], [ Streaming real-time, VoIP, Gaming, DNS, QUIC (HTTP/3) ]
)


= 7. Concetto di Overlay Network

Un'*Overlay Network (Rete Sovrapposta)* è una rete di comunicazione virtuale e logica edificata sopra una rete fisica sottostante (*underlay network*).
- I nodi della rete overlay sono collegati da link logici (es. tunnel TCP/UDP o connessioni P2P).
- *Esempi*: Reti P2P (Chord, BitTorrent), Virtual Private Networks (VPN), Content Delivery Networks (CDN) e reti interne di container (es. Docker/Kubernetes CNI).
