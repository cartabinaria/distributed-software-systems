#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 08",
  subtitle: "Daemon, Oggetti Distribuiti, Componenti, Service Runtimes e Agenti AI",
  author: "Alice Benatti",
  accent-color: rgb("#1a9133")
)

= Posizionamento e Obiettivi Didattici

Nelle lezioni precedenti abbiamo esaminato come i middleware e i canali di comunicazione consentano il passaggio di messaggi disaccoppiati nello spazio e nel tempo. La *Lezione 08* affronta l'analisi degli *endpoint persistenti ed indirizzabili* collocati dietro tali canali: i *daemon* di sistema, gli *oggetti distribuiti*, i *componenti enterprise*, i *service runtime* moderni e gli *agenti AI*.

#callout(title: "Domande Guida per la Progettazione", kind: "definition")[
L'ingegneria del software distribuito richiede la selezione delle opportune astrazioni di astrazione e gestione:
- Quali astrazioni consentono di progettare, costruire e gestire software distribuito scalabile?
- Quali sono le differenze formali tra *Processi*, *Daemon*, *Oggetti*, *Componenti*, *Servizi*, *Framework*, *Container* e *Pacchetti*?
- In che modo le idee nate nell'era CORBA/EJB si sono riorganizzate nell'era Cloud-Native e dei sistemi multi-agente per l'IA?
]

== Risultati di Apprendimento (Learning Outcomes)
Al termine dello studio di questa lezione, lo studente deve essere in grado di:
1. *Spiegare* cos'è un daemon e quali requisiti deve soddisfare un servizio long-running.
2. *Illustrare* le idee durature di definizione delle interfacce (IDL), riferimenti remoti e invocazione stubs/skeletons.
3. *Distinguere* un oggetto da un componente e identificare dove vengono gestiti i requisiti non-funzionali.
4. *Tracciare* la linea evolutiva dagli oggetti distribuiti ai componenti, fino ai runtime di servizio (es. Dapr).
5. *Riconoscere* ciò che lo stub non può nascondere: latenza di rete e guasti parziali.


= Daemon: Requisiti, Supervisione e Logging

== Dai Programmi Convenzionali ai Servizi di Sistema
Quando si sviluppa un server (web, mail, database, autenticazione) e lo si vuole rendere un *servizio di produzione*, l'applicazione deve soddisfare vincoli operativi rigorosi:
- *Disponibilità Continua*: I client possono connettersi in qualsiasi momento; il processo deve rimanere costantemente in esecuzione.
- *Indipendenza dalla Sessione*: Non deve terminare al logout dell'utente o all'invio di segnali da terminale (`Ctrl-C`, `SIGHUP`).
- *Esecuzione Silenziosa in Background*: Deve eseguire senza terminale di controllo (*controlling terminal*).
- *Autonomia e Riavvio Automatico*: Deve funzionare per lunghi periodi senza intervento manuale e riavviarsi automaticamente in caso di crash.
- *Gestione dal Supervisore*: Deve poter essere avviato al boot di sistema o su richiesta (*socket activation*).
- *Concorrenza Sicura e Logging*: Deve gestire richieste concorrenti in modo thread-safe e rendicontare lo stato.

#callout(title: "Definizione di Daemon", kind: "definition")[
Un *Daemon* è un processo di background non associato ad alcun utente interattivo, che esegue compiti continuativi o su richiesta. Non possiede un terminale di controllo e non riceve i segnali generati da tastiera.
]

== Evoluzione dei Daemon: Classici vs Moderni

#table(
  columns: (1.2fr, 1.8fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Ruolo di Sistema* ], [ *Daemon Classico (SysV / BSD)* ], [ *Soluzione Moderna (systemd / Cloud)* ],
  [ *Web Server* ], [ `httpd` ], [ `nginx`, `Apache httpd` ],
  [ *Mail Transfer* ], [ `sendmail` ], [ `Postfix` ],
  [ *Remote Login* ], [ `telnetd`, `rlogind` ], [ `sshd` ],
  [ *Super-Server* ], [ `inetd` ], [ `systemd` (Socket Activation) ],
  [ *System Logging* ], [ `syslogd` ], [ `systemd-journald`, `rsyslog` ],
  [ *Printing* ], [ `lpd` ], [ `CUPS` (`cupsd`) ],
  [ *Supervisione e Init* ], [ SysV init scripts ], [ `systemd` (Linux), `launchd` (macOS) ]
)

== Meccanismi di Daemonizzazione e Modellazione con Service Manager
Storicamente, un programma doveva "daemonizzarsi da solo" seguendo una sequenza di chiamate POSIX:
1. Esecuzione di `fork()` e terminazione immediata del processo padre (rilascia la shell).
2. Invocazione di `setsid()` per creare una nuova sessione e staccarsi dal gruppo di processi e dal terminale di controllo.
3. Seconda `fork()` per impedire al processo di riacquisire un terminale in futuro.
4. Cambio della directory di lavoro a `/` (`chdir("/")`) per non bloccare il unmount dei file system.
5. Reindirizzamento degli stream standard (`stdin`, `stdout`, `stderr`) verso `/dev/null`.
6. Scrittura del PID file e gestione manuale dei segnali (`SIGTERM`, `SIGHUP`).

*Modello Moderno Declarativo*: Nelle architetture moderne basate su `systemd`, il programma *rimane in foreground* e non esegue `fork()` o `setsid()`. Il distacco, il reindirizzamento dei log, il riavvio automatico e i limiti di risorse sono gestiti dal Service Manager tramite file unit di configurazione:

```ini
# /etc/systemd/system/search.service
[Unit]
Description=Search Engine Service
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/search-server
Restart=on-failure
User=search

[Install]
WantedBy=multi-user.target
```

== Daemon Output: Logging e Livelli di Supervisione
Poiché un daemon non ha un terminale, il suo output deve essere instradato verso un servizio di logging dedicato:
- *Syslog (RFC 5424)*: Servizio centralizzato in cui ogni messaggio possiede una *Facility* (origine) e una *Severity* (livello di gravità da Emergency a Debug).
- *systemd-journald*: Raccoglie gli stream `stdout`/`stderr` dei processi in foreground formattandoli in record strutturati.
- *Container*: I processi scrivono su `stdout`/`stderr` e la piattaforma (Docker/Kubernetes) raccoglie ed inoltra i log.

#callout(title: "Distinzione Critica: Liveness vs Readiness", kind: "warning")[
Nei cluster distribuiti e negli orchestratori (es. Kubernetes), la supervisione opera su tre livelli:
1. *Livello Processo*: Il service manager riavvia il programma se crasha (`Restart=on-failure`).
2. *Livello Container*: Criteri di riavvio del container (`always`, `on-failure`).
3. *Livello Cluster*: L'orchestratore applica due tipi di sonde (*probes*):
   - *Liveness Probe*: Verifica se il processo è vivo. Se fallisce, il container viene riavviato.
   - *Readiness Probe*: Verifica se il processo è pronto a servire traffico. *Un processo può essere vivo ma non pronto* (es. fase di caricamento della memoria o ricostruzione della cache).
]

#callout(title: "Quesito di Verifica: Cos'è un Daemon Oggi?", kind: "example")[
*Domanda:* Un server viene eseguito come servizio systemd con `Restart=on-failure`. Il programma non chiama mai `fork()` o `setsid()` e rimane in foreground. È un daemon?

*Risposta Corretta:* *Sì!* Il distacco, la supervisione, la gestione del terminale e il riavvio sono forniti esternamente dal Service Manager. La daemonizzazione da codice è obsoleta.
]


= Oggetti Distribuiti e Middleware CORBA / Java RMI

== Relazione tra Daemon, Servizi e Oggetti
I tre concetti operano a differenti livelli di astrazione:
- *Daemon*: Processo esistente a runtime nell'OS che offre capacità ad utenti, amministratori o altri programmi.
- *Oggetto*: Unità di un programma orientato agli oggetti che incapsula *stato e comportamento*.
- *Servizio*: Insieme di capacità esposte da un'infrastruttura.
- *Middleware*: Software ("software glue") che connette oggetti collocati su macchine differenti fornendo astrazioni di alto livello.

== Cosa Cambia negli Oggetti Distribuiti

#table(
  columns: (1.2fr, 1.8fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Concetto* ], [ *Oggetti Locali* ], [ *Oggetti Distribuiti (Remote Objects)* ],
  [ *Riferimento* ], [ Indirizzo di memoria locale (64-bit) ], [ *Remote Object Reference*: Univoco nello spazio e nel tempo. ],
  [ *Interfaccia* ], [ Interfaccia del linguaggio (Java, C++) ], [ *Remote Interface*: Definita tramite un IDL neutrale. ],
  [ *Invocazione* ], [ Chiamata a funzione locale in stack/CPU ], [ *Distributed Action*: Chiamata remota (RMI/RPC) via rete. ],
  [ *Eccezioni* ], [ Eccezioni di runtime locali ], [ *Distributed Exception*: Gestione esplicita di guasti di rete e timeout. ],
  [ *Garbage Collection* ], [ GC locale automatica in RAM ], [ *Distributed GC*: Opzionale, basato su lease (assente in CORBA). ]
)

== L'Idea Duratura: Interfaccia, Riferimento, Stub e Skeleton
Tutti i framework di invocazione remota condividono il medesimo pattern strutturale:
1. *Interface (IDL)*: Contratto neutrale esplicito che definisce metodi, parametri e tipi.
2. *Reference*: Nome univoco globale per identificare l'oggetto remoto.
3. *Stub (Client Proxy)*: Intermediario locale sul client che esegue il *marshalling* della chiamata.
4. *Skeleton (Server Dispatcher)*: Intermediario sul server che esegue l'unmarshalling e la *dispatch* al servant locale.

== CORBA (Common Object Request Broker Architecture)
Sviluppato dall'OMG (*Object Management Group*, 1989), CORBA è stato il riferimento standard per gli oggetti distribuiti con obiettivo l'interoperabilità tra linguaggi e piattaforme eterogenee.

*Componenti dell'Architettura ORB*:
- *CORBA IDL*: Linguaggio dichiarativo per definire le interfacce indipendentemente dal linguaggio.
- *ORB Core*: Il broker middleware che trasmette richieste e risposte.
- *IIOP (Internet Inter-ORB Protocol)*: Protocollo di rete binario standard per l'interoperabilità tra ORB di vendor differenti.
- *Object Adapter (POA)*: Componente sul server che mappa i riferimenti remoti ai *servant* concreti e gestisce le politiche di attivazione.

#table(
  columns: (1.5fr, 2fr, 1.5fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Servizio CORBA* ], [ *Ruolo nel Middleware* ], [ *Controparte Moderna* ],
  [ *Naming Service* ], [ Mappa nomi simbolici a riferimenti di oggetti. ], [ Service Discovery, DNS, etcd ],
  [ *Trading Service* ], [ Individua oggetti in base ad attributi/proprietà. ], [ Service Registries con metadati ],
  [ *Event / Notification* ], [ Comunicazione asincrona guidata da eventi. ], [ Message Brokers, Pub/Sub ],
  [ *Security Service* ], [ Autenticazione, controllo accessi ed audit. ], [ mTLS, OAuth 2.0 / OIDC ],
  [ *Transaction Service* ], [ Transazioni piatte e annidate distribuite. ], [ Sagas, Distributed Tx ],
  [ *Concurrency Control* ], [ Gestione dei lock su oggetti condivisi. ], [ Distributed locks, Leases ]
)

== Java RMI vs CORBA
- *Interfacce*: CORBA usa un IDL neutrale; Java RMI usa interfacce Java native (*Java-only*).
- *Passaggio Parametri*: In Java RMI, gli oggetti remoti (`Remote`) passano *per riferimento* (viene inviato lo stub), mentre gli oggetti serializzabili (`Serializable`) passano *per valore* (copia integrale dello stato).
- *Distributed Garbage Collection (DGC)*: Java RMI implementa la DGC basata su *lease* temporizzati; CORBA non gestisce la GC distribuita.
- *Evoluzione*: Java IDL e RMI-IIOP sono stati rimossi in Java 11; RMI Activation rimosso in Java 17. Le moderne architetture Java adottano gRPC o API HTTP/REST.

#callout(title: "Quesito di Verifica: Passaggio per Valore in Java RMI", kind: "example")[
*Domanda:* Un client Java RMI chiama `server.register(profile)`, dove `profile` è `Serializable` ma non implementa `Remote`. Il server modifica l'oggetto `profile`. Cosa succede all'oggetto sul client?

*Risposta Corretta:* L'oggetto sul client *rimane del tutto invariato*. Trattandosi di un oggetto `Serializable`, il middleware ne ha inviato una copia conforme per valore. Il server ha modificato la copia locale.
]


= Da Oggetti a Componenti: Contratti, Container e PODA

== La Transizione dai Distribuiti Objects ai Componenti
Gli oggetti distribuiti hanno mostrato limiti legati al troppo stretto accoppiamento e alla gestione manuale della configurazione. L'architettura a componenti rappresenta la naturale evoluzione.

#table(
  columns: (1.2fr, 1.8fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#f0fdf4") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Dimensione* ], [ *Oggetto (Object)* ], [ *Componente (Component)* ],
  [ *Scopo* ], [ Incapsula stato e comportamento. ], [ Unità di composizione con contratti espliciti. ],
  [ *Interfacce* ], [ Espone metodi pubblici. ], [ Dichiara interfacce *Fornite (Provided)* e *Richieste (Required)*. ],
  [ *Identità e Lifecycle* ], [ Gestito esplicitamente dal codice applicativo. ], [ Gestito dal runtime / container. ],
  [ *Granularità* ], [ Fine-grained, prevalentemente in-process. ], [ Granularità variabile, allocabile come unità. ]
)

== Contratti e Architettura dei Container
Un componente è formalmente specificato da un *Contratto*:
- *Provided Interfaces*: Servizi offerti dal componente agli altri moduli.
- *Required Interfaces*: Dipendenze che devono essere presenti ed connesse dall'ambiente affinché il componente possa funzionare.

#callout(title: "Il Ruolo dell'Intercezione nei Container", kind: "definition")[
I componenti vivono all'interno di un *Container* (ospitato da un *Application Server*). Il container *intercetta ogni invocazione in ingresso* applicando in modo trasparente requisiti non-funzionali: sicurezza, gestione transazionale, injection delle dipendenze (CDI), pooling delle istanze e persistenza.
]

== Dal Bytecode alle Immagini: Da WORA a PODA
- *WORA (Write Once Run Anywhere)*: Il medesimo bytecode Java esegue su qualsiasi Virtual Machine.
- *PODA (Package Once Deploy Anywhere)*: I container (Docker) impacchettano l'applicazione unitamente alle sue dipendenze, al sistema operativo base e al runtime. La portabilità si sposta dal livello di bytecode al livello di immagine di sistema.


= Invocazione Remota Moderna: Thrift, gRPC e Waldo's Note

== Apache Thrift
Sviluppato da Facebook (2007) e divenuto progetto Apache nel 2010, Apache Thrift offre un IDL, un generatore di codice ed una libreria runtime per RPC multilinguaggio ad alte prestazioni.
- *Stratificazione*: Stubs generati $	o$ User-defined types $	o$ Protocol (binary, compact, JSON) $	o$ Transport (sockets, HTTP, memory).

== Schema-First RPC: gRPC e Protocol Buffers
gRPC rappresenta l'evoluzione moderna del paradigma IDL con infrastruttura estremamente leggera ("lighter plumbing"):
- Contratto definito tramite schema `.proto`.
- Supporto al multiplexing bidirezionale e streaming nativo su HTTP/2.
- Assenza di un broker o ORB centralizzato complesso da amministrare.

== Ciò che lo Stub NON può Nascondere (Waldo et al.)
Nel celebre saggio del 1994 *A Note on Distributed Computing* (Waldo, Wyant, Wollrath, Kendall), gli autori hanno dimostrato che la trasparenza distributiva totale è un'illusione dannosa.

#callout(title: "Limiti Invalicabili dello Stub", kind: "warning")[
*Ciò che lo stub nasconde*: La sintassi della chiamata remota (simile a quella locale), il marshalling dei dati e la connessione di rete.

*Ciò che lo stub NON può nascondere*:
1. *Latenza*: Una chiamata remota è di ordini di grandezza più lenta rispetto ad un accesso alla RAM.
2. *Guasti Parziali*: Il chiamante o la rete possono fallire a metà invocazione.
3. *Incertezza sui Retry*: Dopo un timeout, il client non sa se l'operazione è stata eseguita. È indispensabile adottare *Idempotency Keys*.
]

#callout(title: "Quesito di Verifica: Significato di DEADLINE_EXCEEDED", kind: "example")[
*Domanda:* Un client invoca un metodo remoto tramite gRPC e riceve lo stato `DEADLINE_EXCEEDED`. Cosa può concludere il client sul server?

*Risposta Corretta:* *La chiamata potrebbe o non potrebbe essere stata eseguita dal server.* Il client sperimenta solo il silenzio di rete e non può discriminare tra perdita del messaggio di richiesta, lentezza del server o perdita della risposta.
]


= Service Runtimes, Dapr, Virtual Actors e Agenti AI

== I Service Runtime Moderni
Nelle architetture Cloud-Native moderne, lo sviluppatore scrive esclusivamente la *logica di business*, mentre la piattaforma / service runtime fornisce in modo trasparente:
- Naming e Service Discovery.
- Health checks, Liveness e Readiness probes.
- Identità sicura tramite mTLS automatico.
- Retries, timeouts, circuit breaking ed osservabilità distribuita.

== Dapr (Distributed Application Runtime)
Progetto CNCF (graduated nel 2024), **Dapr** costituisce l'incarnazione moderna del concetto di intercezione:
- Esegue come un processo **Sidecar** affiancato all'applicazione principale; l'applicazione comunica con Dapr via HTTP o gRPC su `localhost`.
- Fornisce *Building Blocks* pluggabili: service invocation, gestione dello stato, pub/sub, bindings, attori, workflow, gestione segreti e locks.
- Disaccoppia la logica applicativa dall'infrastruttura sottostante senza vendor lock-in.

== Attori Virtuali (Virtual Actors)
Resi popolari da Microsoft Orleans e supportati in Dapr Actors, gli **Attori Virtuali** riportano in auge i concetti di riferimento e ciclo di vita degli oggetti distribuiti:
- *Riferimento*: Un attore è identificato univocamente dalla coppia `(Type, ID)`.
- *Attivazione Trasparente*: Il runtime attiva l'attore in memoria alla prima invocazione e può disattivarlo (*garbage collection degli attori*) quando inattivo.
- *Concorrenza Turn-Based*: Un attore elabora una singola richiesta alla volta, eliminando la complessità dei lock concorrenti.

== Gli Agenti AI Riusano le Idee Classiche del Middleware
Gli agenti autonomi basati su LLM adottano gli stessi modelli architetturali del middleware distribuito:
- Possono eseguire come daemon di background, su richiesta o come task temporanei.
- Scoprono strumenti (*Tools*) e servizi attraverso descrizioni esplicite delle capacità.
- Gli schemi di input dei Tool (es. **JSON Schema**) svolgono esattamente il ruolo di un **IDL**.
- Esempio di riferimento: **Model Context Protocol (MCP)** di Anthropic, basato su JSON-RPC 2.0 (`tools/list`, `tools/call`).

== Una Sola Idea, Quattro Realizzazioni

#table(
  columns: (1.1fr, 1.2fr, 1.2fr, 1.2fr, 1.3fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Concetto* ], [ *Era CORBA* ], [ *Era Componenti* ], [ *Service Runtimes* ], [ *Strumenti Agenti AI* ],
  [ *Interfaccia* ], [ CORBA IDL ], [ Interfacce Componente ], [ Schema `.proto` ], [ JSON Schema del Tool ],
  [ *Riferimento* ], [ Object Reference (IOR) ], [ Home / Remote Handle ], [ Service Endpoint ], [ Server + Tool Name ],
  [ *Invocazione* ], [ ORB Call ], [ Container Interception ], [ Generated Stub Call ], [ `tools/call` (JSON-RPC) ],
  [ *Supervisione* ], [ Process Manager / Daemon ], [ Application Server ], [ Framework + Platform ], [ Agent Host / Scheduler ]
)


= Sintesi e Punti Chiave (Takeaways)

1. *L'idea di base è costante*: La sequenza *Interfaccia $	o$ Riferimento $	o$ Stub $	o$ Skeleton* è il principio guida immutato che lega CORBA, gRPC, Dapr e gli Agenti AI.
2. *Rilocalizzazione della responsabilità*: I problemi distribuiti (ciclo di vita, persistenza, sicurezza, retries) non scompaiono; la responsabilità si è semplicemente spostata dai framework in-process verso i sidecar ed i runtime di piattaforma.
3. *Lo stub non nasconde la fisica*: Nessun middleware o astrazione generativa può azzerare la latenza o eliminare l'incertezza dei guasti parziali.
