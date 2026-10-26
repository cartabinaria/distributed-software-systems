#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 06: Comunicazione Indiretta",
  accent-color: rgb("#1a9133")
)

// --- SEZIONE 1 ---
= 1. Introduzione alla Comunicazione Indiretta e Tassonomia del Disaccoppiamento

== 1.1 La Transizione dai Modelli Diretti all'Indirezione
Nei paradigmi di comunicazione diretta esaminati nelle lezioni precedenti — quali le Socket TCP/UDP, le chiamate Request-Reply e i framework di Remote Procedure Call (RPC) e Remote Method Invocation (RMI) — il flusso informativo poggia su un *accoppiamento stretto* tra i processi partecipanti. Nell'invocazione diretta, l'emittente deve conoscere l'indirizzo fisso di rete (indirizzo IP e porta) del destinatario, ed entrambe le entità devono risultare contemporaneamente attive ed esecutive per consentire l'instaurazione del canale di trasporto.

Questo modello incontra limiti invalicabili nei contesti distribuiti moderni caratterizzati da elevata dinamicità, eterogeneità, mobilità delle componenti o elaborazione di flussi ad altissima densità (IoT, microservizi cloud-native, sistemi finanziari, coordinamento di agenti IA). La *comunicazione indiretta* supera la rigidità del modello diretto interponendo un intermediario software tra emittenti e destinatari, sbloccando tre dimensioni fondamentali di disaccoppiamento (*uncoupling*):

#callout(
  title: "Le Tre Dimensioni del Disaccoppiamento nella Comunicazione Indiretta",
  fill-color: rgb("#eff6ff"),
  stroke-color: rgb("#93c5fd"),
  title-color: rgb("#1e40af")
)[
  - *Disaccoppiamento Spaziale (Space Uncoupling / Referential Uncoupling)*: L'emittente non conosce e non necessita di conoscere l'identità, il numero o l'indirizzo IP/porta dei destinatari. Allo stesso modo, i destinatari consumano dati senza conoscere l'entità che li ha prodotti.
  - *Disaccoppiamento Temporale (Time Uncoupling)*: L'emittente e i destinatari non devono essere contemporaneamente attivi né connessi alla rete. Un messaggio può essere inviato mentre i destinatari sono offline, memorizzato dall'infrastruttura e consumato in un momento successivo.
  - *Disaccoppiamento di Flusso (Synchronization / Flow Uncoupling)*: Le operazioni di invio e ricezione non bloccano l'esecuzione dei processi. L'emittente rilascia il messaggio in modalità asincrona (*fire-and-forget* o *non-blocking*) e prosegue la propria computazione senza attendere la risposta o la conferma di lettura.
]

== 1.2 Mappa dei Paradigmi di Comunicazione Indiretta
L'architettura della comunicazione indiretta si articola in cinque paradigmi principali, classificabili in base allo stile di servizio (basato su comunicazione o basato su stato) e al pattern di interazione ($1->"molti"$ oppure $1->1$):

1. *Group Communication (Comunicazione di Gruppo)*: Invio di messaggi da un'origine verso un insieme astratto di processi interconnessi (*multicast*).
2. *Publish-Subscribe Systems (Sistemi Pub/Sub)*: Disseminazione di eventi orientata a canale, soggetto o contenuto gestita da una rete di broker intermediari.
3. *Streaming Platforms (Piattaforme di Event Streaming)*: Log di commit distribuiti e persistenti per l'elaborazione continua e ad alta velocità di flussi di eventi (es. Apache Kafka).
4. *Message Queues (Code di Messaggi)*: Comunicazione punto-a-punto punto-a-punto ($1->1$) basata su code persistenti gestite da Queue Manager (es. IBM MQ, JMS).
5. *Distributed Shared Memory (DSM) e Spazi di Tuple*: Astrazioni basate sullo stato condiviso in cui i processi interagiscono scrivendo e leggendo tuple tramite pattern matching associativo (es. Linguaggio Linda).


// --- SEZIONE 2 ---
= 2. Group Communication (Comunicazione di Gruppo)

== 2.1 Definizione di Gruppo e Primitiva di Multicast
La comunicazione di gruppo consente a un processo sorgente di trasmettere dati a molteplici processi destinatari contemporaneamente. Un *gruppo* costituisce una collezione astratta di processi interconnessi in cui l'infrastruttura di comunicazione nasconde il passaggio fisico dei messaggi, facendo apparire la trasmissione come un'unica operazione logica.

Si distinguono quattro modalità principali di indirizzamento:
- *Unicast*: Comunicazione punto-a-punto tra un singolo mittente e un singolo destinatario.
- *Broadcast*: Trasmissione di un messaggio a tutti i nodi appartenenti alla medesima sottorete fisica.
- *Multicast*: Trasmissione indirizzata simultaneamente a un sottoinsieme specifico di nodi destinatari.
- *Anycast*: Consegna del messaggio a un qualsiasi singolo membro appartenente al gruppo (tipicamente il più vicino in termini di metrica di instradamento).

#callout(
  title: "Tipi di Gruppo: Aperti, Chiusi e Sovrapposti",
  fill-color: rgb("#f8fafc"),
  stroke-color: rgb("#cbd5e1"),
  title-color: rgb("#0f172a")
)[
  - *Gruppo Chiuso (Closed Group)*: Solamente i processi membri del gruppo hanno la facoltà di inviare messaggi in multicast al gruppo stesso. Quando un membro invia un messaggio, questo viene consegnato anche a se stesso.
  - *Gruppo Aperto (Open Group)*: Processi esterni al gruppo possono inviare messaggi in multicast ai membri del gruppo.
  - *Gruppi Sovrapposti (Overlapping Groups)*: Un processo può appartenere contemporaneamente a più gruppi distinti. Nei sistemi distribuiti reali, i gruppi sovrapposti rappresentano lo scenario di riferimento.
]

L'uso del multicast risulta cruciale per:
1. *Tolleranza ai guasti*: Mediante la replicazione dei servizi su più nodi (servizi replicati).
2. *Service Discovery*: Localizzazione dinamica dei servizi in reti spontanee o ad-hoc.
3. *Prestazioni e Caching*: Propagazione rapida degli aggiornamenti sulle repliche di dati.
4. *Notifica di Eventi*: Disseminazione reattiva dei cambiamenti di stato.

== 2.2 Ordinamento dei Messaggi Multicast
Nelle primitive di rete di basso livello (es. UDP multicast), la sequenza di arrivo dei pacchetti presso i diversi destinatari è intrinsecamente non deterministica a causa dei ritardi variabili dei canali. I servizi di comunicazione di gruppo offrono garanzie formali di *ordinamento del multicast*:

#table(
  columns: (1.3fr, 2.7fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#e2e8f0") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  align: (col, row) => if row == 0 { center } else { left },
  [ *Tipo di Ordinamento* ], [ *Definizione e Proprietà Formale* ], [ *Implicazioni e Garanzie* ],
  [ *FIFO Ordering* \ (Source Ordering) ], [ Se un processo $P$ invia il messaggio $m_1$ prima di $m_2$, tutti i processi del gruppo consegnano $m_1$ prima di $m_2$. ], [ Garantisce l'ordine sequenziale dei messaggi generati dallo *stesso* mittente. Non impone vincoli tra emittenti diversi. ],
  [ *Causal Ordering* ], [ Se l'invio del messaggio $m_1$ *happens-before* ($m_1->m_2$) l'invio del messaggio $m_2$, tutti i membri consegnano $m_1$ prima di $m_2$. ], [ Preserva le relazioni causali espresse dal tempo logico di Lamport o Vector Clocks nell'intero sistema distribuito. ],
  [ *Total Ordering* ], [ Se il messaggio $m_1$ viene consegnato prima di $m_2$ presso un processo, la medesima sequenza è rispettata presso *tutti* i processi del gruppo. ], [ Assicura che tutti i nodi vedano esattamente la stessa sequenza. Non implica FIFO o Causalità (da cui gli ibridi *FIFO-Atomic*, *Causal-Total*). ]
)

== 2.3 Gestione della Membership e Sincronia Virtuale (*Virtual Synchrony*)
Nelle applicazioni reali, la composizione dinamica del gruppo varia nel tempo a causa di processi che entrano (*Join*), escono volontariamente (*Leave*) o collassano inavvertitamente (*Fail*).

Un servizio di *Group Membership Management* mantiene una vista accurata e coerente dei membri attivi. L'evoluzione del gruppo viene rappresentata formalmente come una sequenza discreta di *Viste* ($V_0, V_1, V_2, dots$). Un passaggio da $V_i$ a $V_{i+1}$ costituisce un *View Change*.

#callout(
  title: "Il Principio della Sincronia Virtuale (Birman & Joseph, sistema ISIS)",
  fill-color: rgb("#f0fdf4"),
  stroke-color: rgb("#86efac"),
  title-color: rgb("#166534")
)[
  La *Sincronia Virtuale* è una proprietà fondamentale che garantisce che tutti i messaggi multicast siano consegnati *all'interno della medesima vista* in cui sono stati inviati.
  
  *Proprietà Chiave:* Se un processo $P$ invia un messaggio $m$ mentre il gruppo si trova nella vista $V_i$, il messaggio $m$ viene consegnato da *tutti* i processi superstiti che passano da $V_i$ a $V_{i+1}$ *prima* che il cambio di vista $V_{i+1}$ venga eseguito, oppure non viene consegnato da *nessuno*.
  
  In questo modo, i cambiamenti di appartenenza e la consegna dei messaggi appaiono come eventi barriera perfettamente sincronizzati per tutti i nodi, semplificando la gestione dello stato nei sistemi replicati (*State Machine Replication*).
]


// --- SEZIONE 3 ---
= 3. Sistemi Publish-Subscribe (Pub/Sub)

== 3.1 Architettura e Modello Funzionale
I sistemi Publish-Subscribe realizzano un disaccoppiamento completo in spazio e tempo tra i produttori di dati (*Publishers*) e i consumatori (*Subscribers*). La comunicazione è mediata da un *Notification Service* (o rete di *Broker*).

I Publisher pubblicano *Eventi* (o notifiche) senza indirizzarli a nodi specifici. I Subscriber esprimono il proprio interesse verso determinate categorie di eventi tramite *Sottoscrizioni* (*Subscriptions*). Il servizio di notifica effettua il matching tra gli eventi in ingresso e le sottoscrizioni attive, provvedendo al recapito.

== 3.2 Tassonomia delle Varianti Pub/Sub
I sistemi Pub/Sub si classificano in base all'espressività del linguaggio di sottoscrizione:

1. *Channel-based (Basato su Canali)*:
   - I Publisher inviano eventi a canali con nome predefinito. I Subscriber si iscrivono a un canale e ricevono *tutti* gli eventi transitanti su di esso.
   - *Esempio storico:* CORBA Event Service (usato ad esempio nei sistemi di controllo e robotica per riconfigurare al volo le sorgenti di sensori).
2. *Topic-based / Subject-based (Basato su Soggetti/Topic)*:
   - Ogni notifica contiene un campo esplicito che ne definisce il *topic* (spesso organizzato in gerarchie alfanumeriche come `news/sports/soccer`). I Subscriber definiscono filtri su tali stringhe (anche con wildcard come `news/sports/#`).
   - *Esempio classico:* Protocollo MQTT per l'Internet of Things (IoT) gestito da broker come HiveMQ o Mosquitto.
3. *Content-based (Basato sul Contenuto)*:
   - Rappresenta la forma più generale ed espressiva. Le sottoscrizioni sono espresse come predicati booleani o vincoli di intervallo su molteplici attributi interni della notifica (es. `symbol = "AAPL" AND volume > 100`).
   - *Esempi classici:* Sistemi Siena, Gryphon, TIB/Rendezvous.

== 3.3 Architettura a Livelli e Routing degli Eventi
La distribuzione scalabile delle notifiche in una rete di broker richiede algoritmi avanzati di *Event Routing*:

- *Flooding*: La notifica viene inviata in broadcast a tutti i nodi della rete di broker; il filtraggio sul contenuto viene eseguito sul nodo terminale del subscriber.
- *Filtering / Selective Routing*: I broker inoltrano le notifiche *esclusivamente* lungo i percorsi dell'overlay network che conducono a subscriber attivi con filtri corrispondenti.
- *Advertisements*: I publisher dichiarano preventivamente la tipologia di eventi che intenderanno pubblicare. I broker utilizzano gli *advertisements* per indirizzare le sottoscrizioni solo verso le regioni di rete interessate, riducendo drasticamente il traffico di segnalazione.
- *Rendezvous Networks*: Lo spazio degli eventi è partizionato deterministicamente tra i broker della rete (tramite DHT o funzioni di hash); un determinato tipo di evento viene instradato verso il *rendezvous broker* preposto.


// --- SEZIONE 4 ---
= 4. Case Studies: Piattaforme di Event Streaming e Messaging

== 4.1 Apache Kafka: Log di Commit Distribuito
*Apache Kafka* (originariamente sviluppato da LinkedIn) rappresenta la piattaforma di event streaming distribuita di riferimento per architetture ad altissima scala. A differenza dei broker Pub/Sub tradizionali in cui i messaggi vengono eliminati subito dopo la consegna, Kafka gestisce i dati come un *append-only commit log distribuito e persistito su disco*.

#callout(
  title: "Architettura Fondamentale di Apache Kafka",
  fill-color: rgb("#fefce8"),
  stroke-color: rgb("#fde047"),
  title-color: rgb("#854d0e")
)[
  - *Topic e Partizioni*: I dati sono organizzati in *Topic*. Ogni Topic è suddiviso in più *Partizioni* distribuite tra i *Broker* del cluster per garantire bilanciamento del carico e scalabilità orizzontale.
  - *Produttori e Consumatori*: I produttori eseguono un *push* delle notifiche verso i broker. I consumatori eseguono un *pull* leggendo i dati in modo asincrono.
  - *Offsets e Consumer Groups*: Ogni messaggio all'interno di una partizione possiede un identificatore numerico sequenziale e immutabile chiamato *Offset*. I consumatori sono organizzati in *Consumer Groups*: ciascun messaggio inviato a una partizione viene consegnato a una sola istanza all'interno del gruppo, consentendo l'elaborazione parallela.
  - *Gestione del Cluster (KRaft)*: Storicamente basato su Apache ZooKeeper, Kafka ha introdotto *KRaft (Kafka Raft Metadata Mode)* per la gestione interna del consenso e dei metadati. A partire da *Kafka 4.0 (2025)*, ZooKeeper è stato completamente rimosso.
]

I casi d'uso aziendali testimoniano volumi di traffico straordinari: LinkedIn elabora oltre 4.5 trilioni di messaggi al giorno, mentre Netflix gestisce oltre 1 trilione di messaggi quotidiani (con picchi di 6 Petabyte di dati in streaming). Kafka costituisce inoltre la spina dorsale per pipeline di Machine Learning (Feature Data Input, Schema Registry, KSQL, Model Training).

== 4.2 Panoramica sulle Piattaforme di Streaming Moderne
- *Apache Pulsar*: Architettura cloud-native caratterizzata dal disaccoppiamento tra il livello computazionale dei broker (*stateless*) e il livello di memorizzazione persistente basato su *Apache BookKeeper*. Integra *Pulsar Functions* per lo stream processing serverless.
- *Amazon Kinesis*: Suite di servizi gestiti su AWS che comprende *Kinesis Data Streams*, *Kinesis Video Streams*, *Amazon Data Firehose* (ingestione diretta in data lake) e *Managed Service for Apache Flink*.
- *Google Cloud Pub/Sub*: Servizio di messaggistica globale cloud-managed, fully serverless, integrato con le pipeline di data processing *Google Cloud Dataflow* e *BigQuery*.
- *Redis (Pub/Sub vs. Streams)*:
  - *Redis Pub/Sub Channels*: Modello *fire-and-forget* non persistente. Se un subscriber è offline al momento della pubblicazione, il messaggio va definitivamente perduto.
  - *Redis Streams*: Struttura dati persistente basata su log *append-only* con supporto a *Consumer Groups* e *Acknowledgements* (ACK), concettualmente affine a Kafka.


// --- SEZIONE 5 ---
= 5. Message Queues (Code di Messaggi)

== 5.1 Il Paradigma delle Code di Messaggi
Le *Message Queues* forniscono un modello di comunicazione indiretta e asincrona incentrato sul pattern punto-a-punto ($1->1$). I *produttori* inviano messaggi a una specifica coda di destinazione; i *consumatori* estaggono i messaggi dalla coda.

Il consumo delle notifiche supporta tre stili operativi:
1. *Blocking receive*: Il consumatore si blocca in attesa finché un messaggio non diviene disponibile nella coda.
2. *Non-blocking receive (Polling)*: Il consumatore interroga la coda; se presente, ottiene il messaggio, altrimenti riceve una segnalazione immediata di coda vuota.
3. *Notify (Asynchronous Listener)*: L'infrastruttura di queuing notifica in modo reattivo il consumatore tramite un evento non appena un messaggio viene depositato.

== 5.2 IBM MQ (formerly WebSphere MQ)
*IBM MQ* costituisce il middleware di queuing enterprise di riferimento in contesti finanziari e industriali. Un *Queue Manager* gestisce i contenitori fisici delle code e provvede all'instradamento dei messaggi verso altri Queue Manager tramite *canali* unidirezionali o bidirezionali. Le applicazioni client remote comunicano con il Queue Manager attraverso *Client Channels* basati su proxy/stub.

== 5.3 Jakarta Messaging (formerly Java Message Service - JMS)
In ambiente Java enterprise, *Jakarta Messaging (JMS)* definisce lo standard industriale API per l'accesso a sistemi di messaggistica.

Il modello di programmazione JMS si articola nelle seguenti entità:
- *ConnectionFactory*: Oggetto amministrativo utilizzato per creare connessioni verso il provider.
- *Connection*: Canale logico attivo sopra il trasporto di rete (es. TCP/IP).
- *Session*: Contesto single-threaded per la creazione di *MessageProducer*, *MessageConsumer* e *Message*.
- *Destination*: Entità astratta che rappresenta una *Queue* (pattern punto-a-punto) o un *Topic* (pattern pub/sub).

Nelle transazioni complesse (es. scenario Retailer-Vendor-Suppliers), JMS consente di gestire il flusso asincrono tramite il campo header `JMSReplyTo`, che indica la coda temporanea di risposta su cui il fornitore deve inviare le conferme di evasione dell'ordine.


// --- SEZIONE 6 ---
= 6. Memoria Condivisa Distribuita (DSM) e Spazi di Tuple

== 6.1 Distributed Shared Memory (DSM)
La *Distributed Shared Memory (DSM)* è un'astrazione software/hardware che offre l'illusione di uno spazio di memoria primario condiviso tra nodi fisicamente distribuiti e privi di memoria fisica comune. I processi leggono e modificano variabili nello spazio virtuale condiviso, mentre il middleware DSM gestisce la coerenza della pagina e il recupero della memoria via rete.

== 6.2 L'Astrazione dello Spazio di Tuple e il Linguaggio Linda
Introdotto da *David Gelernter* (Università di Yale, 1985) all'interno del linguaggio di coordinamento *Linda*, lo *Spazio di Tuple (*Tuple Space*)* rappresenta una delle forme più eleganti di comunicazione indiretta basata sullo *stato condiviso*.

Un tuple space è un *multiset* globale distribuito contenente *Tuple* (sequenze ordinate di valori tipizzati, es. `<"Capital", "Italy", "Rome">`). I processi comunicano non scambiando messaggi diretti, ma inserendo ed estraendo tuple dallo spazio mediante *indirizzamento associativo per contenuto* (*associative matching*).

#callout(
  title: "Primitive Fondamentali del Modello Linda",
  fill-color: rgb("#fbfbfe"),
  stroke-color: rgb("#c7d2fe"),
  title-color: rgb("#3730a3")
)[
  - `write(tuple)` / `out(tuple)`: Inserisce una nuova tuple nello spazio condiviso (operazione non bloccante).
  - `read(template)` / `rd(template)`: Cerca nello spazio una tuple che soddisfi il *template* specificato e ne restituisce una copia. Se nessuna tuple corrisponde, il processo chiamante *si blocca* finché una tuple valida non viene inserita.
  - `take(tuple)` / `in(template)`: Cerca una tuple corrispondente al *template*, ne restituisce il valore e la *rimuove definitivamente* dallo spazio di tuple (operazione bloccante).
]

#v(0.5em)
*Esempio di Associative Matching:*
Un processo esegue `rd(<"Capital", "Italy", ?String>)`. Il sistema ricerca nello spazio una tuple la cui firma corrisponda ai primi due valori letterali; la variabile wildcard `?String` viene legata atomicamente al valore `"Rome"`.

L'astrazione dello spazio di tuple garantisce il massimo grado di disaccoppiamento spaziale e temporale (i processi non si conoscono e la tuple può sopravvivere al processo che l'ha generata). Sistemi moderni basati su questo modello includono *JavaSpaces* e *GigaSpaces*.


// --- SEZIONE 7 ---
= 7. Matrice Comparativa degli Stili di Comunicazione Indiretta

A completamento dell'analisi, la seguente matrice mette a confronto in modo sistematico i cinque stili di comunicazione indiretta trattati nella Lezione 06:

#table(
  columns: (1.2fr, 1fr, 1fr, 1.2fr, 1.1fr, 2.2fr),
  fill: (x, y) => if y == 0 { rgb("#e2e8f0") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  align: (col, row) => if row == 0 { center } else { left },
  [ *Stile di Comunicazione* ], [ *Disaccoppiato in Spazio?* ], [ *Disaccoppiato in Tempo?* ], [ *Stile del Servizio* ], [ *Pattern di Comunicazione* ], [ *Obiettivo e Caso d'Uso Elettivo* ],
  [ *Group Communication* ], [ Sì ], [ Possibile \ (in base al buffer) ], [ Basato su comunicazione ], [ $1->"molti"$ ], [ Computazione distribuita affidabile, servizi replicati e tolleranza ai guasti. ],
  [ *Publish-Subscribe* ], [ Sì ], [ Possibile \ (se persistente) ], [ Basato su comunicazione ], [ $1->"molti"$ ], [ Disseminazione eventi, integrazione aziendale (EAI), IoT e mobile systems. ],
  [ *Message Queues* ], [ Sì ], [ Sì ], [ Basato su comunicazione ], [ $1->1$ \ (punto-a-punto) ], [ Integrazione di applicazioni enterprise, elaborazione asincrona di transazioni. ],
  [ *Distributed Shared Memory (DSM)* ], [ Sì ], [ Sì ], [ Basato su stato ], [ $1->"molti"$ ], [ Calcolo parallelo su cluster e condivisione di memoria ad alte prestazioni. ],
  [ *Tuple Spaces (Linda)* ], [ Sì ], [ Sì ], [ Basato su stato ], [ $1->1$ oppure $1->"molti"$ ], [ Coordinamento disaccoppiato di flussi di lavoro, microblogging e concorrenza. ]
)
