#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 17",
  subtitle: "Coordinazione, Mutua Esclusione, Elezione e Consenso nei Sistemi Distribuiti",
  author: "Alice Benatti",
  accent-color: rgb("#1a9133")
)

= Il Problema della Coordinazione nei Sistemi Distribuiti

Nei sistemi centralizzati monolitici, la presenza di una memoria primaria condivisa e di un unico sistema operativo permette di sincronizzare i processi mediante primitive a basso livello come semafori, mutex o sezioni critiche hardware. Nei sistemi distribuiti, invece, la presenza di nodi autonomi interconnessi da reti prive di memoria condivisa e prive di un orologio fisico globale rende la coordinazione una delle sfide fondamentali dell'informatica.

== Le Tre Necessità della Coordinazione
Come introdotto nelle lezioni precedenti e formalizzato nella Lezione 17, la coordinazione distribuita si articola in tre problemi chiave:

#align(center)[
#table(
  columns: (1.2fr, 1.8fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  align: (col, row) => if row == 0 { center + horizon } else { left + horizon },
  [ *Esigenza Applicativa* ], [ *Problema Architetturale* ], [ *Esempi Industriali Reali* ],
  [ *Accesso esclusivo a una risorsa comune* ], [ *Mutua Esclusione Distribuita* ], [ Lock per risorse condivise in etcd, ZooKeeper e Google Chubby. ],
  [ *Designazione di un nodo coordinatore* ], [ *Elezione del Leader (Leader Election)* ], [ Controller di Apache Kafka (KRaft), Master di Kubernetes, Primary nei DB distribuiti. ],
  [ *Accordo unanime su una decisione o log* ], [ *Consenso Distribuito (Consensus)* ], [ Commit/Abort di transazioni, ordinamento delle transazioni in CockroachDB e Spanner. ]
)
]

== Modello di Sistema e Classificazione dei Guasti
Per analizzare gli algoritmi di coordinazione, si definisce il modello teorico del sistema:
- *Processi*: $N$ processi indipendenti $P = {p_1, p_2, dots, p_N}$. Un numero al più pari a $f$ processi può subire guasti, mentre i restanti $N - f$ si definiscono *corretti*.
- *Canali di Comunicazione*: Assecondano la trasmissione mediante scambio di messaggi (*message passing*). I canali si assumono *affidabili* (nessun messaggio viene corrotto o duplicato, e tutti i messaggi inviati tra nodi corretti vengono eventualmente consegnati).
- *Modelli di Guasto dei Processi*:
  - *Crash-Stop / Crash-Recovery*: Un processo guasto smette improvvisamente di funzionare (o si riavvia perdendo lo stato volatile).
  - *Guasti Bizantini (Arbitrari)*: Un processo guasto o malevolo invia messaggi arbitrari, contraddittori o alterati (*liars*).

#callout(title: "Il Problema dei Due Generali (Two Generals Problem)", kind: "warning")[
Due armate situate sulle colline opposte devono attaccare contemporaneamente una città nella valle: un attacco coordinato garantisce la vittoria, mentre un attacco isolato porta alla disfatta. La comunicazione avviene tramite messaggeri che attraversano la valle e possono essere catturati (canale inaffidabile con perdita di messaggi).

*Risultato di Impossibilità (Akkoyunlu et al. 1975, Gray 1978)*: Non esiste alcun protocollo finito basato su scambio di messaggi su un canale inaffidabile in grado di garantire con certezza l'accordo tra i due generali. Ogni messaggio di conferma (*ACK*) richiede a sua volta una conferma (*ACK dell'ACK*), generando una catena infinita di incertezza. Nei Due Generali i processi sono onesti ma il canale è inaffidabile; nel problema dei Generali Bizantini il canale è affidabile ma i processi possono mentire.
]

== Failure Detectors e Partizioni di Rete
Un *Failure Detector* è un servizio locale che risponde alla domanda: _"Il processo $p$ è guasto?"_.
- *Failure Detector Inaffidabile*: Risponde con *Suspected* o *Unsuspected*. A causa di latenze di rete o pause della Garbage Collection (GC), un nodo corretto può essere ingiustamente sospettato (*false positive*).
- *Failure Detector Affidabile*: Risponde con *Failed* solo quando il guasto è certo. Realizzabile unicamente in sistemi strettamente *sincroni*.
- *Phi Accrual Failure Detector*: Adottato in Cassandra e Akka, calcola un livello continuo di sospetto ($phi$) basato sullo storico dei tempi di arrivo degli *heartbeat*, anziché usare un timeout rigido.

In presenza di una *Partizione di Rete*, il cluster viene diviso in sottogruppi incapaci di comunicare tra loro. Poiché la connettività può essere *asimmetrica* ($p$ raggiunge $q$, ma $q$ non raggiunge $p$) o *intransitiva*, i nodi sviluppano viste divergenti su chi sia attivo, rendendo indispensabile progettare algoritmi che garantiscano la sicurezza (*safety*) anche durante le partizioni.


= Mutua Esclusione Distribuita

Il problema della mutua esclusione distribuita consiste nel garantire che al più un processo alla volta possa accedere a una *sezione critica* (o risorsa condivisa) in assenza di memoria condivisa e di un orologio globale.

== Requisiti Formali (ME1, ME2, ME3)
Ogni algoritmo di mutua esclusione distribuita deve soddisfare tre proprietà fondamentali:
1. *ME1 - Safety (Mutua Esclusione)*: Al più un processo alla volta può eseguire all'interno della sezione critica.
2. *ME2 - Liveness (Assenza di Deadlock e Starvation)*: Le richieste di entrare e uscire dalla sezione critica completano eventualmente con successo. Nessun processo attende indefinitamente.
3. *ME3 - Ordering (Fairness Causale)*: Se la richiesta di entrata dell'evento $a$ precede l'evento $b$ secondo la relazione *happened-before* ($a -> b$), l'accesso viene concesso ad $a$ prima che a $b$.

=== Metriche Ingegneristiche di Confronto
- *Consumo di Banda*: Numero di messaggi scambiati per ciascuna entrata ed uscita dalla sezione critica.
- *Latenza del Client*: Tempo necessario ad accedere alla sezione critica quando questa è libera.
- *Synchronization Delay (Ritardo di Sincronizzazione)*: Tempo che intercorre tra l'uscita di un processo dalla sezione critica e l'entrata del processo successivo. Determina il *throughput* massimo del sistema.

== Algoritmi Classici a Confronto

=== Algoritmo a Server Centralizzato
Un server coordinatore gestisce il token e una coda FIFO di richieste.
- *Entrata*: 2 messaggi (Request, Grant). *Uscita*: 1 messaggio (Release). *Sync Delay*: 2 tempi di messaggio.
- *Verifica*: Soddisfa ME1 e ME2. *Non soddisfa ME3* (le richieste vengono servite nell'ordine di arrivo al server, che può differire dall'ordine causale *happened-before* di invio).
- *Limiti*: Il server è un collo di bottiglia e un *Single Point of Failure* (SPOF). Se il coordinatore o il processo detentore del token crasha, il sistema si blocca.

=== Algoritmo Token Ring
I processi sono organizzati in un anello logico unidirezionale. Un unico *token* circola continuamente lungo l'anello.
- *Funzionamento*: Un nodo che riceve il token ed ha bisogno della risorsa entra in sezione critica; al termine (o se non ne ha bisogno) passa il token al successore.
- *Prestazioni*: Messaggi per entrata da $0$ a $N$. *Sync Delay*: da $1$ a $N$ passi.
- *Limiti*: Consuma banda costantemente anche quando nessun nodo richiede la risorsa. La perdita del token richiede l'avvio di una complessa procedura di rigenerazione.

=== Algoritmo di Ricart-Agrawala (Permission-Based)
Basato sugli *Orologi Logici di Lamport*, richiede che un processo ottenga il permesso da *tutti* gli altri nodi prima di entrare.
- *Funzionamento*: Per entrare, $p_i$ invia in multicast un messaggio $< T_i, p_i >$ recante il timestamp di Lamport corrente. Un nodo $p_j$ risponde immediatamente con OK a meno che non sia a sua volta in sezione critica o desideri entrarvi con un timestamp *minore* di $< T_i, p_i >$ (in tal caso pospone la risposta).
- *Prestazioni*: $2(N - 1)$ messaggi per entrata. *Sync Delay*: 1 tempo di messaggio.
- *Verifica*: *Soddisfa ME1, ME2 e ME3* (gli orologi di Lamport garantiscono un ordine totale equo).
- *Punto Debole*: Basta che un singolo processo della rete passi in crash e non risponda per bloccare l'intero sistema.

=== Algoritmo di Maekawa (Quorum-Based)
Anziché chiedere il permesso a tutti i nodi, ciascun processo $p_i$ richiede il voto solo a un sottoinsieme di nodi denominato *Voting Set* $V_i$.
- *Regola dei Quorum*: Gli insiemi di voto sono costruiti in modo che due insiemi qualsiasi si intersechino sempre: $forall i, j, V_i section V_j != emptyset$. Disponendo i nodi su una griglia $sqrt(N) times sqrt(N)$, ciascun $V_i$ è formato dagli elementi della riga e della colonna di $p_i$ (dimensione $approx 2 sqrt(N)$).
- *Prestazioni*: $approx 2 sqrt(N)$ messaggi per entrata, $approx sqrt(N)$ per l'uscita. *Sync Delay*: 2.
- *Rischio Deadlock*: Può generare deadlock se i voti si incrociano; si risolve ordinando le richieste tramite timestamp di Lamport.

#align(center)[
#table(
  columns: (1.2fr, 1.2fr, 1fr, 1fr, 0.8fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  align: (col, row) => if row == 0 { center + horizon } else { left + horizon },
  [ *Algoritmo* ], [ *Messaggi Entrata* ], [ *Uscita* ], [ *Sync Delay* ], [ *ME3* ], [ *Punto Debole Principale* ],
  [ *Centralizzato* ], [ 2 ], [ 1 ], [ 2 ], [ No ], [ SPOF e bottleneck sul server coordinatore. ],
  [ *Token Ring* ], [ da 0 a $N$ ], [ 1 ], [ da 1 a $N$ ], [ No ], [ Traffico continuo in inattività; perdita del token. ],
  [ *Ricart-Agrawala* ], [ $2(N - 1)$ ], [ $<= N - 1$ ], [ 1 ], [ **Sì** ], [ Un singolo nodo guasto blocca tutti gli altri. ],
  [ *Maekawa* ], [ $approx 2 sqrt(N)$ ], [ $approx sqrt(N)$ ], [ 2 ], [ Con fix ], [ Rischio di deadlock se non integrato con orologi logici. ]
)
]

== Lock Distribuiti nella Pratica: Leases e Fencing Tokens
Nessuno degli algoritmi teorici distribuiti classici tollera i guasti senza modifiche sostanziali. Nella pratica industriale si utilizzano *Lock Service Replicati* (Chubby, ZooKeeper, etcd) basati sulle seguenti garanzie:

- *Leases (Affitti Temporizzati)*: Un lock viene concesso con una scadenza temporale (*TTL*). Se il detentore va in crash o perde la connettività, il lease scade e il lock viene liberato automaticamente.
- *Fencing Tokens (Token di Recinzione)*: Un contatore intero strettamente crescente ritornato dal server del lock ad ogni concessione. Le risorse di storage sottostanti accettano operazioni solo se accompagnate da un fencing token maggiore di quello registrato fino a quel momento.

#callout(title: "Perché i Lease da soli non bastano? Il problema delle GC Pauses", kind: "warning")[
Si consideri un Client 1 che acquisisce un lease (Token 33). Subito dopo, il Client 1 subisce una pausa prolungata della Garbage Collection (o uno stall del sistema operativo). Durante la pausa, il lease scade. Il Lock Service assegna il lock al Client 2 (Token 34), che scrive sullo storage.

Quando il Client 1 si risveglia dalla GC pause, ritiene erroneamente di possedere ancora il lock e tenta di scrivere sullo storage. Senza *Fencing Token*, il Client 1 sovrascriverebbe e corromperebbe i dati del Client 2. Con il Fencing Token, lo storage confronta il token del Client 1 (33) con quello memorizzato (34) e *rifiuta l'operazione obsoleta*.
]


= Algoritmi di Elezione del Leader

Il problema dell'elezione consiste nel designare un unico processo tra quelli attivi affinché assuma un ruolo di coordinamento (es. Master in un DB, Controller in Kafka).

== Requisiti Formali (E1, E2)
Assumendo che ogni processo $p_i$ possieda un identificatore univoco $"id"(p_i)$:
- *E1 - Safety*: Tutti i partecipanti non guasti eleggono lo stesso processo (quello attivo con l'ID più alto), oppure l'elezione è ancora in corso.
- *E2 - Liveness*: Tutti i partecipanti alla fine eleggono un leader o vanno in crash.

== Algoritmo Ring (Chang e Roberts)
Organizza i nodi in un anello logico unidirezionale.
1. Un processo che rileva il guasto del leader invia un messaggio `ELECTION(id)` al proprio successore.
2. Alla ricezione di `ELECTION(k)`:
   - Se $k > "id"_"locale"$, il nodo inoltra `ELECTION(k)`.
   - Se $k < "id"_"locale"$, il nodo sostituisce $k$ con il proprio $"id"_"locale"$ e inoltra `ELECTION(`$"id"_"locale"$`)`.
   - Se $k == "id"_"locale"$, il nodo ha completato il giro ed è il vincitore: invia un messaggio `ELECTED(`$"id"_"locale"$`)` lungo l'anello.
- *Costo*: Nel caso peggiore $3N - 1$ messaggi. Presuppone l'assenza di guasti durante l'elezione.

== Algoritmo Bully (Prepotente)
Assume un sistema *sincrono* con timeout affidabili.
1. Un processo $p_k$ invia un messaggio `ELECTION` a tutti i nodi con ID strettamente maggiore ($p_{k+1}, dots, p_N$).
2. Se nessuno risponde entro il timeout, $p_k$ vince e invia `COORDINATOR` a tutti i nodi con ID inferiore.
3. Se un nodo con ID superiore risponde `OK`, $p_k$ si fa da parte. Il nodo con ID superiore avvia la propria elezione.
- *Bullying*: Un nodo con ID alto che rientra in rete prevarica (*bullies*) il leader corrente avviando un'elezione e prendendo il controllo.
- *Costo*: Da $N - 2$ messaggi nel caso migliore a $O(N^2)$ nel caso peggiore.
- *Limite*: Se i timeout di rete sono stimati male, il sistema elegge molteplici leader violando E1.

== Elezioni Reali e Prevenzione dello Split-Brain
Nei cluster reali suddivisi da partizioni di rete, può verificarsi la condizione di *Split-Brain* (due sottogruppi eleggono ciascuno un proprio leader ed accettano scritture concorrenti). I sistemi moderni prevengono lo Split-Brain tramite:
- *Maggioranze Assolute*: Un nuovo leader può essere eletto ed operare solo se ottiene il voto di una *maggioranza stretta dei nodi* ($N/2 + 1$).
- *Termini ed Epoche (Terms / Epochs)*: Contatori progressivi incrementati a ogni elezione. Messaggi inviati da vecchi leader recanti termini obsoleti vengono rifiutati dai nodi.
- *Implementazioni Industriali*:
  - *Raft*: Timeout casuali di candidatura ed elezione a maggioranza per termine.
  - *ZooKeeper*: Creazione di nodi sequenziali effimeri (*lowest sequence node wins*).
  - *Kubernetes*: I controller rinnovano periodicamente una risorsa `Lease` su etcd.


= Il Problema del Consenso Distribuito

Il consenso è il problema fondamentale dei sistemi distribuiti: una collezione di processi deve concordare unicamente su un singolo valore o su una sequenza di operazioni.

== Definizione Formale del Consenso
Ciascun processo $p_i$ propone un valore iniziale $v_i in V$. Al termine dell'algoritmo, ciascun processo corretto imposta la propria decisione $d_i in V$.
- *Termination (Liveness)*: Ogni processo corretto alla fine decide un valore.
- *Agreement (Safety)*: Tutti i processi corretti decidono lo stesso identico valore ($d_i = d_j$).
- *Integrity / Validity (Safety)*: Se tutti i processi corretti hanno proposto lo stesso valore $v$, ogni processo corretto deve decidere $v$.

=== Equivalenza dei Problemi
Nei sistemi con canali affidabili, i seguenti problemi sono dimostrabilmente equivalenti (risolto uno, si possono risolvere tutti gli altri): Consenso, Problema dei Generali Bizantini, Consistenza Interattiva e Multicast ad Ordine Totale (*Atomic Broadcast*).

== Generali Bizantini (Guasti Arbitrari)
Introdotto da Lamport, Shostak e Pease (1982), considera un Comandante ed $N - 1$ Luogotenenti in cui un numero $f$ di attori può essere traditore (inviare informazioni false o contraddittorie).

#callout(title: "Limite dei Tre Generali (N <= 3f)", kind: "definition")[
Con messaggi non firmati, *non esiste alcuna soluzione se $N <= 3f$*. 
Per tollerare $f$ processi bizantini occorrono almeno *$N >= 3f + 1$ processi* e $f + 1$ round di comunicazione.
]
*Dimostrazione Intuitiva ($N=3, f=1$)*: 
Se $p_1$ è il comandante e $p_2, p_3$ sono luogotenenti:
1. *Caso A (Luogotenente $p_3$ traditore)*: Il comandante $p_1$ invia "Attacca" ad entrambi. $p_3$ dice a $p_2$ che $p_1$ gli ha detto "Ritirata".
2. *Caso B (Comandante $p_1$ traditore)*: Il comandante invia "Attacca" a $p_2$ e "Ritirata" a $p_3$. $p_3$ dice la verità a $p_2$ ("$p_1$ mi ha detto Ritirata").

Dal punto vista di $p_2$, i messaggi ricevuti nei due casi sono *esattamente identici* ($p_1$ dice Attacca, $p_3$ dice Ritirata). $p_2$ non può distinguere il comandante traditore dal luogotenente traditore.

== Il Teorema FLP (Fischer, Lynch, Paterson 1985)

#callout(title: "Teorema FLP di Impossibilità del Consenso", kind: "warning")[
In un sistema distribuito *completamente asincrono*, non esiste alcun algoritmo di consenso deterministico in grado di garantire la liveness se *anche un solo processo può subire un guasto di tipo crash* ($f >= 1$).
]
*Intuizione della Dimostrazione*: In un sistema asincrono, non è possibile distinguere un processo che è andato in crash da un processo che è semplicemente estremamente lento o rallentato dalla rete. L'algoritmo può rimanere bloccato indefinitamente in uno *stato bivalente* senza mai poter decidere in modo sicuro.

=== Come i Sistemi Reali Superano il Teorema FLP
Poiché nella pratica i sistemi devono operare, le architetture moderne aggirano il teorema FLP modificandone le assunzioni:
1. *Sincronia Parziale (Partial Synchrony)*: Si assume che il sistema sia asincrono per la maggior parte del tempo, ma che esistano periodi di stabilità in cui i ritardi di rete sono delimitati. Algoritmi come Paxos e Raft sono *sempre safe* (non violano mai l'accordo) e diventano *live* non appena la rete entra in un periodo di sincronia parziale.
2. *Algoritmi Randomizzati*: Utilizzano scelte probabilistiche (es. moneta lanciata casualmente) per uscire dagli stati bivalenti con probabilità 1.
3. *Failure Detectors Eventualmente Accurati*: Modelli con detectors che alla fine smettono di generare falsi sospetti.


= Protocolli di Consenso Pratici: Paxos e Raft

== Paxos (Lamport 1998 / Paxos Made Simple 2001)
Paxos è il protocollo di consenso di riferimento per i sistemi industriali ad alta affidabilità (Google Spanner, Chubby).

=== Ruoli del Protocollo
- *Proposers*: Propongono i valori dai client.
- *Acceptors*: Memorizzano lo stato e votano sulle proposte (formano la memoria persistente del cluster).
- *Learners*: Apprendono il valore deciso ed eseguono le operazioni.

=== Fasi del Protocollo Basic Paxos
Un valore viene scelto quando viene accettato da una *maggioranza di Acceptor*.
1. *Fase 1a - Prepare*: Il Proposer seleziona un numero di proposta univoco e crescente $n$ e invia `Prepare(n)` alla maggioranza degli Acceptor.
2. *Fase 1b - Promise*: Se $n$ è superiore a qualsiasi proposta vista prima, l'Acceptor risponde con `Promise(n)`, promettendo di rifiutare proposte $< n$, e ritornando l'eventuale valore di numero più alto già accettato $(n_"accepted", v_"accepted")$.
3. *Fase 2a - Accept*: Ricevuta la maggioranza di promesse, il Proposer seleziona il valore $v$: se gli Acceptor hanno ritornato valori precedenti, $v$ *deve essere il valore associato alla proposta più alta ricevuta*; altrimenti sceglie il proprio valore. Invia `Accept(n, v)`.
4. *Fase 2b - Accepted*: Se l'Acceptor non ha promesso di ignorare $n$, accetta $(n, v)$ e notifica i Learners.

#callout(title: "Multi-Paxos e Dueling Proposers", kind: "info")[
In *Basic Paxos*, due Proposer concorrenti possono scavalcarsi a vicenda all'infinito incrementando i numeri di proposta prima che l'altro completi la Fase 2 (*livelock*). *Multi-Paxos* risolve questo problema eleggendo un unico Proposer stabile (Leader) ed eseguendo la Fase 1 un'unica volta per un'intera sequenza di log.
]

== Raft (Ongaro e Ousterhout 2014)
Nato per superare l'estrema complessità di Paxos, Raft scompone il consenso in tre sotto-problemi indipendenti: Elezione del Leader, Replicazione del Log e Safety.

=== Stati e Funzionamento
- Ciascun nodo si trova in uno di tre stati: *Follower*, *Candidate*, o *Leader*.
- Il tempo è diviso in *Termini* (*Terms*) numerati progressivamente.

1. *Elezione del Leader*: Se un Follower non riceve *heartbeat* prima del timeout di elezione (casuale tra 150ms e 300ms per evitare *split-vote*), diventa Candidate, incrementa il Termine e richiede i voti. Vince chi ottiene la maggioranza dei voti dal cluster.
2. *Replicazione del Log*: Il Leader riceve i comandi dai client, li appende al proprio log e li invia ai Follower tramite messaggi `AppendEntries`.
3. *Commit*: Un'entrata di log si definisce *Committed* quando è stata replicata con successo sulla maggioranza dei nodi del cluster. Il Leader applica quindi l'operazione alla propria macchina a stati e risponde al client.

=== Proprietà di Safety di Raft
- *Election Safety*: Al più un leader può essere eletto per termine.
- *Leader Append-Only*: Il leader non sovrascrive né tronca mai i propri log.
- *Log Matching Property*: Se due log contengono un'entrata con lo stesso indice e termine, sono identici in tutti gli indici precedenti.
- *Leader Completeness*: Se un'entrata è committed in un termine, sarà presente nei log dei leader di tutti i termini successivi (un Candidate non può vincere l'elezione se il suo log è meno aggiornato della maggioranza).

== Panoramica Industriale del Consenso in Produzione

#align(center)[
#table(
  columns: (1.5fr, 1.2fr, 2.3fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  align: (col, row) => if row == 0 { center + horizon } else { left + horizon },
  [ *Sistema Industriale* ], [ *Protocollo Adottato* ], [ *Oggetto del Consenso e Ruolo* ],
  [ *etcd* (Kubernetes) ], [ Raft ], [ Stato globale del cluster, configurazioni, lock e lease dei controller. ],
  [ *ZooKeeper* (Hadoop, HBase) ], [ Zab (variante Paxos) ], [ Configurazione di cluster, coordinamento e appartenenza ai nodi. ],
  [ *Kafka KRaft* ], [ Raft (metadata log) ], [ Gestione metadata di cluster ed elezione controller (sostituisce ZooKeeper da Kafka 4.0). ],
  [ *CockroachDB / TiKV* ], [ Raft (per Range) ], [ Ogni *range* di dati di 64MB costituisce un gruppo Raft indipendente per le scritture. ],
  [ *Google Spanner / Chubby* ], [ Multi-Paxos ], [ Replication group delle partizioni di database e lock service ad altissima disponibilità. ]
)
]


= Esercizi Pratici Svolti

== Esercizio su Elezione su Anello Logico (Chang e Roberts)
Si consideri un anello logico di 6 processi disposti in senso orario: $P_5, P_12, P_3, P_20, P_8, P_15$.
Il processo $P_3$ rileva il guasto del vecchio leader ed avvia un'elezione.

1. *Tracciamento del messaggio di Elezione*:
   - $P_3$ invia `ELECTION(3)` a $P_20$.
   - $P_20$ riceve `3`. Poiché $20 > 3$, sostituisce il valore ed invia `ELECTION(20)` a $P_8$.
   - $P_8$ riceve `20`. Poiché $8 < 20$, inoltra `ELECTION(20)` a $P_15$.
   - $P_15$ riceve `20`. Poiché $15 < 20$, inoltra `ELECTION(20)` a $P_5$.
   - $P_5$ riceve `20`. Poiché $5 < 20$, inoltra `ELECTION(20)` a $P_12$.
   - $P_12$ riceve `20`. Poiché $12 < 20$, inoltra `ELECTION(20)` a $P_3$.
   - $P_3$ riceve `20`. Poiché $3 < 20$, inoltra `ELECTION(20)` a $P_20$.
   - $P_20$ riceve `ELECTION(20)` recante il proprio ID: *$P_20$ è il nuovo leader!*
2. *Fase di Proclamazione*:
   - $P_20$ invia il messaggio `ELECTED(20)` a compiere l'intero giro dell'anello (6 messaggi).
3. *Conteggio Messaggi Totali*: 7 messaggi di elezione + 6 messaggi di coordinatore = *13 messaggi*.

== Esercizio su Valutazione Quorum e Fault Tolerance in Raft / etcd
Un cluster `etcd` composto da 5 membri esegue il protocollo Raft.

1. *Quanti membri possono andare in crash mantenendo il cluster operativo in scrittura?*
   - *Risposta*: *2 membri*. 
   - *Motivazione*: Per eleggere un leader e committare transazioni, Raft richiede una maggioranza stretta del cluster: $Q = floor(N / 2) + 1 = floor(5 / 2) + 1 = 3$. Se 2 nodi vanno in crash, rimangono 3 nodi attivi, in grado di formare la maggioranza. Se 3 nodi vanno in crash, rimangono solo 2 nodi (minoranza), ed il cluster si blocca in scrittura per preservare la *Safety*. In generale, $2f + 1$ nodi tollerano $f$ guasti da crash.