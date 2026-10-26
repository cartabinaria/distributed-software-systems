#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 02",
  subtitle: "Modelli Fisici, Fondamentali e Architetturali nei Sistemi Distribuiti",
  accent-color: rgb("#1a9133")
)

= 1. Tassonomia dei Modelli dei Sistemi Distribuiti

Nei sistemi distribuiti, la complessità deriva dalla presenza di più nodi autonomi che comunicano esclusivamente tramite scambio di messaggi, in assenza di un orologio globale e con la possibilità di guasti parziali. Per analizzare, progettare e verificare tali sistemi si utilizzano tre livelli di astrazione e modellazione:

- *Modelli Fisici (Physical Models)*: Considerano l'hardware, i tipi di dispositivi e le interconnessioni di rete, prescindendo dai dettagli tecnologici specifici (es. presenza o assenza di memoria condivisa).
- *Modelli Fondamentali (Fundamental Models)*: Astrazioni teoriche per analizzare e risolvere i problemi trasversali degli algoritmi distribuiti (sincronizzazione del tempo, semantica dei guasti e modelli di sicurezza).
- *Modelli Architetturali (Architectural Models)*: Descrivono la struttura software del sistema, la suddivisione in componenti, i ruoli e i paradigmi di comunicazione (es. Client-Server, Peer-to-Peer, Microservizi, Middleware).


= 2. Modelli Fisici (Physical Models)

I modelli fisici studiano come la CPU e la memoria sono organizzate ed interconnesse a livello hardware. Si classificano in quattro architetture principali:

#callout(title: "Classificazione delle Architetture Hardware", kind: "definition")[
1. *Memoria Fisicamente Condivisa (UMA / Cache-Coherent Interconnect)*: Più processori ($P$) accedono a un unico spazio di indirizzamento di memoria fisica tramite un bus ad alta velocità con coerenza della cache gestita nativamente dall'hardware.
2. *Interconnessione senza Coerenza di Cache (NUMA)*: I processori dispongono di memoria locale distinta e sono interconnessi senza un meccanismo hardware automatico di coerenza della cache; la gestione deve avvenire via software.
3. *Memoria Distribuita Condivisa (Distributed Shared Memory - DSM)*: La memoria fisica è distribuita tra nodi distinti, ma un layer software/hardware crea un'astrazione di spazio di memoria condivisa globale.
4. *Macchine in Rete (Networked Machines / Cluster)*: Ogni nodo è un computer indipendente con propria CPU e memoria locale, interconnesso ad altri tramite rete (LAN/WAN). *È il modello di riferimento per i sistemi distribuiti moderni.*
]


= 3. Modelli Fondamentali (Fundamental Models)

I modelli fondamentali forniscono le basi matematiche ed astratte per verificare la correttezza degli algoritmi distribuiti.

== 3.1 Gestione del Tempo e dell'Interazione (Interaction Model)
Nei sistemi distribuiti *non esiste un orologio fisico globale*. I modelli di interazione si dividono formalmente in base alla presenza o assenza di limiti temporali (*bounds*):

1. *Sistemi Distribuiti Sincroni (Synchronous Systems)*:
  - *Proprietà formali*:
    1. Esistono un limite inferiore e uno superiore noti sul tempo di esecuzione dei passi di calcolo dei processi.
    2. I messaggi inviati in rete vengono consegnati entro un intervallo di tempo massimo noto ($D$).
    3. Il tasso di deriva (*drift rate*) tra gli orologi locali dei singoli nodi ha un limite massimo noto e limitato.
  - *Conseguenze*: È possibile definire una nozione di tempo fisico globale. *Rilevamento dei guasti certo*: se una risposta non giunge entro il timeout calcolato, il nodo o canale è sicuramente guasto (Fail-Stop).
  - *Svantaggio*: Costosi e difficili da realizzare nell'infrastruttura reale su vasta scala.

2. *Sistemi Distribuiti Asincroni (Asynchronous Systems)*:
  - *Proprietà formali*: Nessun limite noto (*no bounds*) su velocità dei processi, ritardi di consegna dei messaggi in rete o deriva degli orologi locali.
  - *Conseguenze*: Non si può usare il tempo fisico per ordinare gli eventi; occorre utilizzare il *tempo logico* (es. relazione *Happened-Before* di Lamport o Vector Clocks).
  - *Ambiguità dei Timeout*: Un timeout scaduto non garantisce che il nodo sia morto: potrebbe essere lento o la rete congestionata.
  - *Uso pratico*: Rappresenta la quasi totalità dei sistemi reali (Internet, Web e Cloud).

== 3.2 Tassonomia dei Modelli di Guasto (Fault / Failure Models)

#table(
  columns: (1.2fr, 2.5fr, 1.5fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Tipo di Guasto* ], [ *Descrizione e Semantica* ], [ *Rilevabilità / Note* ],
  [ *Guasti di Omissione (Fail-Stop)* ], [ Un processo o canale omette di eseguire un'azione dovuta (es. send/receive omission). Se produce un output, questo è sicuramente corretto. ], [ Nei sistemi sincroni vengono rilevati in modo certo tramite timeout. ],
  [ *Guasti Temporali (Timing Faults)* ], [ Si verificano quando si superano i limiti temporali pattuiti di risposta, ritardo di rete o deriva del clock. ], [ Possono manifestarsi solo nei sistemi sincroni. ],
  [ *Guasti Bizantini (Arbitrary Faults)* ], [ La semantica più severa ("worst case"). Un nodo può inviare dati falsi, risposte contraddittorie o agire in modo malevolo. ], [ Richiedono almeno $N = 3f + 1$ nodi totali per tollerare $f$ nodi corrotti. ]
)

== 3.3 Modello di Sicurezza (Security Model)
I canali di comunicazione su rete pubblica non sono sicuri per natura:

#callout(title: "Il Modello dell'Avversario (The Enemy)", kind: "warning")[
L'avversario può effettuare quattro tipi di attacco sul canale:
- *Eavesdrop*: Intercettare e leggere i messaggi in transito.
- *Modify*: Alterare il contenuto del messaggio.
- *Inject*: Iniettare messaggi falsi o duplicati.
- *Block*: Bloccare o ritardare la consegna dei messaggi.
]

Per contrastare l'avversario si definisce il *Canale Sicuro (Secure Channel)*, che garantisce tre proprietà essenziali:
1. *Autenticazione dei Principal*: Ciascun processo conosce con certezza l'identità dell'altra parte.
2. *Riservatezza e Integrità*: Protezione da letture non autorizzate e rilevamento di qualsiasi manomissione dei dati.
3. *Protezione da Replay e Freschezza*: Inclusione di timestamp fisici/logici o *nonce* (numeri univoci) per impedire il re-invio di vecchi messaggi.


= 4. Modelli Architetturali e Coordinamento

Un *Stile Architetturale (Architectural Style)* definisce la struttura logica e fisica del software in termini di:
- *Componenti*: Unità modularizzate con interfacce ben definite (fornite e richieste), sostituibili a caldo.
- *Connettori (Connectors)*: Meccanismi software che gestiscono la comunicazione, il coordinamento o la cooperazione tra componenti (es. RPC, Message Queues, Sockets, Streaming).
- *Configurazione*: La topologia con cui componenti e connettori sono assemblati.

== 4.1 Paradigmi di Coordinamento: La Matrice di Gelernter-Carriero

I paradigmi di comunicazione e coordinamento si classificano in base al grado di disaccoppiamento nello spazio e nel tempo:

#table(
  columns: (1.5fr, 1.8fr, 1.8fr),
  fill: (x, y) => if y == 0 { rgb("#f0fdf4") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Disaccoppiamento* ], [ *Accoppiato nel Tempo (Sincrono)* ], [ *Disaccoppiato nel Tempo (Asincrono)* ],
  [ *Accoppiato nello Spazio* ], [ *Chiamata Diretta / Sockets / RPC*: Mittente e destinatario devono conoscersi ed essere attivi contemporaneamente. ], [ *Message Queues (1-to-1)*: Il mittente conosce il nome della coda ma il destinatario può prelevare il messaggio in seguito. ],
  [ *Disaccoppiamento Spaziale* ], [ *Multicast di Gruppo / Publish-Subscribe Sincrono*: Il mittente non conosce i destinatari ma tutti devono essere attivi. ], [ *Spazi di Tuple (Linda) / Event-Streams*: Totale disaccoppiamento spaziale e temporale mediante memoria associativa condivisa. ]
)

#callout(title: "Il Modello a Tuple di Linda", kind: "definition")[
Introdotto da Gelernter (Yale, 1985), il modello Linda permette a processi indipendenti di comunicare inserendo e prelevando tuple da uno *Spazio di Tuple (Tuple Space)* condiviso tramite pattern matching associativo:
- `write(t)`: Aggiunge la tupla `t` allo spazio di tuple.
- `read(template)`: Legge (senza rimuovere) una tupla corrispondente al template. Bloccante se non presente.
- `take(template)`: Legge e rimuove atomicamente una tupla corrispondente dal tuple space.
]

== 4.2 Stili Architetturali Principali

1. *Client-Server*:
  - *2-Tier*: Suddivisione tra client e server (*Fat Client* con logica applicativa sul client vs *Thin Client* con logica sul server).
  - *3-Tier*: Separazione in Presentation Tier (UI), Business Logic Tier (Application Server) e Data Tier (Database Cluster).
2. *Peer-to-Peer (P2P)*: Architettura simmetrica in cui ogni nodo funge sia da client che da server (*servant*). Si dividono in *Non Strutturati* (flooding) e *Strutturati* (basati su Distributed Hash Tables - DHT come Chord).
3. *Service-Oriented e Microservizi*: Decomposizione in servizi autonomi, loose coupling, comunicazione via API leggere (REST/gRPC) e orchestrazione tramite API Gateway.

== 4.3 Il Percorso di Scalabilità Web in 6 Step

#table(
  columns: (0.8fr, 2.2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Step* ], [ *Configurazione Architetturale* ], [ *Obiettivo e Soluzione* ],
  [ *1* ], [ Single Server (App + DB sullo stesso nodo) ], [ Prototipo iniziale, idoneo per bassissimo traffico. ],
  [ *2* ], [ Separazione di App Server e DB Server ], [ Elimina la competizione per risorse CPU/RAM sul singolo nodo. ],
  [ *3* ], [ Multiple App Servers + Load Balancer ], [ Scalabilità orizzontale del livello web. Richiede livello stateless. ],
  [ *4* ], [ Scalabilità del DB (Read Replicas) ], [ Separazione delle letture (su repliche) dalle scritture (sul Master). ],
  [ *5* ], [ Caching Layer (Redis) & Sharding ], [ Riduce il carico sul DB tramite cache in-memory e partizionamento. ],
  [ *6* ], [ Microservizi & Distributed Architecture ], [ Decomposizione per domini di business con DB indipendenti. ]
)


= 5. Frontiere Moderne: Cloud, Edge e Multi-Agente AI

Le moderne architetture evolvono verso l'integrazione di:
- *Cloud Elastic Computing*: Autoscaling dinamico basato sul carico e risorse serverless on-demand.
- *Edge Computing*: Spostamento della computazione e del caching a bassa latenza in prossimità dei dispositivi client/IoT.
- *Orchestrazione Multi-Agente per GenAI*: Sistemi distribuiti specializzati nel training parallelizzato di modelli (data/model parallelism) e nell'orchestrazione di agenti intelligenti cooperanti.
