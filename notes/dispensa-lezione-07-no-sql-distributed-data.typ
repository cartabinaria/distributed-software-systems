#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Distributed Data: NoSQL and Beyond",
  subtitle: "Modelli di Dati, Meccanismi di Distribuzione, Garanzie di Consistenza e Architetture dei Sistemi Distribuiti per i Dati",
  accent-color: rgb("#1a9133")
)

= Introduzione e Modelli di Dati (Data Models)

== Le Tre V dei Dati e le Dimensioni del Workload
Storicamente, la spinta verso il movimento NoSQL e la riprogettazione dei sistemi di gestione delle basi di dati è stata motivata dall'insorgere di carichi di lavoro su scala globale caratterizzati dalle cosiddette *Tre V*:

- *Volume*: La dimensione dei dati è passata da gigabyte/terabyte gestibili su un singolo server a petabyte ed esabyte distribuiti su cluster di centinaia o migliaia di nodi.
- *Velocity*: La velocità di arrivo dei dati è diventata continua ed elevatissima; le elaborazioni batch tradizionali hanno ceduto il passo all'ingestione e all'analisi in tempo reale (*streaming*).
- *Variety*: La forma dei dati si è diversificata; le tabelle relazionali rigide non sono più l'unico modello naturale per rappresentare documenti JSON annidati, grafi di connessioni sociali o serie temporali ad alta frequenza.

#callout(title:"Fatto Architetturale Fondamentale")[
  Le *Tre V* definiscono le *dimensioni del workload* (carico di lavoro) che hanno motivato la nascita dei primi sistemi NoSQL. Tuttavia, esse *non determinano le garanzie di consistenza* offerte da un sistema. La scelta del modello di dati determina quali query risultano naturali ed efficienti, non come i dati vengono distribuiti o quanto siano consistenti.
]

== Tassonomia dei Modelli di Dati
Un modello di dati definisce l'astrazione attraverso cui l'applicazione struttura, memorizza ed interroga le informazioni. La Lezione 07 individua cinque modelli di dati primari:

1. *Key-Value Store*: Un valore opaco (array di byte, stringa, oggetto) è indirizzato univocamente da una chiave primaria. Le operazioni fondamentali sono `get(key)`, `put(key, value)` e `delete(key)`. Esempio: sessioni utente o carrelli della spesa (`cart:42 -> [skuA, skuB]`).
2. *Document Store*: Registri auto-descrittivi annidati (strutturati in formato JSON, BSON o XML). Permettono query ricche sui campi interni ed indici secondari. Esempio: schede prodotto (`{ id: 12, name: "lamp", attrs: { watt: 9, color: "red" } }`).
3. *Wide-Column Store (Column-Family)*: Le righe sono raggruppate per *partition key* e ordinate internamente per *clustering columns*. Permettono di memorizzare ed interrogare insiemi dinamici di colonne sparse. Esempio: log di eventi utente per timestamp (`user_7 | 09:01 | view`, `user_7 | 09:03 | add`).
4. *Graph Database*: Entità rappresentate come nodi ed interazioni rappresentate come archi tipizzati orientati (*edges*), entrambi dotati di proprietà (*property graph*). Ottimizzati per attraversamenti multi-hop. Esempio: reti sociali o raccomandazioni (`Ann -[BOUGHT]-> lamp -[SIMILAR]-> desk`).
5. *Relational Database (RDBMS / Distributed SQL)*: Tabelle normalizzate divise in righe e colonne, vincoli d'integrità referenziale, operazioni di join complesse, transazioni ACID e linguaggio dichiarativo SQL.

== Modellazione ad Aggregati vs Normalizzazione Relazionale
La decisione chiave nella modellazione dei dati consiste nello stabilire quali informazioni devono essere lette ed aggiornate insieme:

- *Modello Relazionale (Normalizzato)*: Le entità risiedono in tabelle distinte (`orders`, `order_items`) e vengono ricombinate a tempo di esecuzione tramite operazioni di *JOIN*. Questo elimina la duplicazione dei dati e rende naturali le query trasversali (ad esempio calcolare le vendite complessive di un articolo), ma richiede l'accesso a più righe/tabelle potenzialmente collocate su nodi diversi.
- *Modello a Documenti (Inserimento / Embedding)*: L'intero aggregato (l'ordine unitamente ai suoi articoli) viene memorizzato come un unico documento atomicamente coeso.
  ```json
  {
    "order_id": 42,
    "customer": "C7",
    "items": [
      { "sku": "A", "qty": 2 },
      { "sku": "B", "qty": 1 }
    ]
  }
  ```
  L'inserimento (*embedding*) rende l'accesso all'aggregato estremamente rapido (una singola lettura disk/network su un unico nodo), ma rende dispendiose le aggregazioni analitiche su singoli campi annidati attraverso l'intero database.

== Demitizzazione del NoSQL (NoSQL Myths)
Il termine "NoSQL" (*Not Only SQL*) è un'etichetta storica e non una specifica architetturale. La Lezione 07 smonta tre falsi miti comunemente associati a NoSQL:

#table(
  columns: (1.2fr, 2fr, 2fr),
  align: (left, left, left),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("#E9ECEF") } else { none },
  [*Falso Mito*], [*Realtà dell'Ingegneria del Software*], [*Controesempi Significativi*],
  [NoSQL = Schemaless], [Molti sistemi NoSQL impongono schemi rigidi o contratti fortemente tipizzati.], [Cassandra (schema CQL esplicito e tipi), HBase.],
  [NoSQL = Nessuna Transazione], [Molti store NoSQL supportano transazioni atomiche su singolo documento o multi-documento.], [MongoDB (transazioni ACID multi-documento), Redis (blocco EXEC).],
  [NoSQL = Eventual Consistency], [La consistenza è un parametro configurabile; molti NoSQL offrono consistenza forte/linearizzabile.], [MongoDB (majority read/write concern), HBase (consistenza forte per riga).]
)


= Meccanismi di Distribuzione dei Dati (Data Distribution)

== Scale Up vs Scale Out
Per gestire la crescita dei dati e delle richieste, un'architettura può adottare due strategie di scalabilità:

- *Scale Up (Scalabilità Verticale)*: Aumento delle risorse hardware (CPU, RAM, dischi NVMe) su un singolo server centralizzato. Presenta un posizionamento dei dati semplice e nessuna coordinazione distribuita, ma è limitata dai costi e costituisce un *Single Point of Failure* (SPOF).
- *Scale Out (Scalabilità Orizzontale)*: Aggiunta di nuovi nodi di calcolo ed architettura *shared-nothing* interconnessi via rete. Garantisce crescita incrementale e ridondanza, ma sposta l'onere della gestione del partizionamento, della coordinazione e dei guasti parziali sul software.

== Partizionamento (Sharding)
Il partizionamento suddivide l'insieme complessivo delle chiavi in porzioni disgiunte chiamate *shards* o *partizioni*. Ogni record appartiene a esattamente una partizione. Vi sono due strategie primarie:

1. *Range Partitioning*: Lo spazio delle chiavi viene suddiviso in intervalli contigui (es. Shard A: chiavi 0--99, Shard B: 100--199).
   - *Vantaggio*: Le scansioni per intervallo (*range queries*) rimangono locali al singolo shard.
   - *Svantaggio*: Rischio elevato di *hotspot* sulle scritture in presenza di chiavi monotonicamente crescenti (es. timestamp o ID progressivi).
2. *Hash Partitioning*: Un'operazione di hashing applicata alla chiave ($h = "hash"(k) mod S$) determina lo shard di destinazione.
   - *Vantaggio*: Distribuzione uniforme e bilanciata del carico di lavoro tra i nodi.
   - *Svantaggio*: Le scansioni per intervallo devono essere trasmesse a tutti gli shards (*scatter-gather query*).
3. *Consistent Hashing*: Mappa sia i nodi che le chiavi su un anello logico di token ($0 dots 2^{128}-1$). Minimizza la quantità di dati da riposizionare quando un nodo entra o esce dal cluster.

== Criteri di Scelta della Partition Key
La scelta della *partition key* costituisce una decisione architetturale irreversibile; modificarla in seguito impone la migrazione fisica dell'intero dataset. I criteri di scelta prevedono:

- Prioritizzare i pattern di lettura e scrittura dominanti.
- Evitare hotspot evitando ID monotonici, timestamp grezzi o chiavi ad elevatissima popolarità (*celebrity keys*).
- Preservare la *località di dati*: fare in modo che i record aggiornati o letti insieme risiedano nello stesso shard.

== Replicazione: Leader-Based vs Leaderless
Partizionamento e Replicazione sono dimensioni ortogonali: un sistema con $N$ shards ed $R$ repliche mantiene $R$ copie distinte di ciascuno dei suoi $N$ shards.

```
                  [Shard A]           [Shard B]           [Shard C]
Replica 1  --->  (Nodo 1: Leader)   (Nodo 2: Follower)  (Nodo 3: Follower)
Replica 2  --->  (Nodo 2: Follower) (Nodo 3: Leader)    (Nodo 1: Follower)
Replica 3  --->  (Nodo 3: Follower) (Nodo 1: Follower)  (Nodo 2: Leader)
```

- *Replicazione Leader-based (Primary-Backup)*: Un singolo nodo eletto (*Leader*) ordina tutte le scritture all'interno di un log replicato; i *Followers* applicano il log localmente. In caso di crash del leader, occorre un'elezione e il meccanismo di *fencing* per isolare il vecchio leader. Esempi: MongoDB replica sets, Raft.
- *Replicazione Leaderless (Dynamo-style)*: Nessun nodo funge da leader primario. Il client (o un nodo coordinatore) trasmette le letture e le scritture direttamente a multiple repliche. I conflitti vengono riconciliati tramite quorumi di lettura/scrittura, *read repair* ed *anti-entropy*. Esempi: Cassandra, Riak.

== L'Impatto dei Guasti Parziali
Nei sistemi distribuiti reali, i guasti si manifestano in forme complesse: crash di processi, partizioni di rete (in cui nodi vivi non riescono a comunicare), ritardi arbitrari nei messaggi ed aggiornamenti concorrenti su repliche distinte.

#callout(title:"Principio dell'Inconoscibilità")[
  Dall'esterno di un nodo remoto, un processo estremamente lento a causa della memoria satura e un processo definitivamente andato in crash sono del tutto indistinguibili. I *timeout* non consentono di discriminare tra lentezza ed arresto.
]


= Garanzie, Consistenza e Tolleranza ai Guasti (Guarantees)

== Transazioni ACID vs Filosofia BASE

#grid(
  columns: (1fr, 1fr),
  gutter: 12pt,
  [
    #rect(width: 100%, fill: rgb("#EFF6FF"), inset: 10pt, stroke: 1pt + rgb("#3B82F6"))[
      #text(weight: "bold", fill: rgb("#1D4ED8"))[Transazioni ACID (Garantismo)]
      - *Atomicity*: Tutto o niente.
      - *Consistency*: Mantenimento degli invarianti di dominio dell'applicazione.
      - *Isolation*: Controllo della concorrenza (es. Serializzabile, Snapshot Isolation).
      - *Durability*: I dati committati sopravvivono ai guasti.
      *Nota*: La consistenza ACID è un vincolo di stato applicativo, non è la "C" del teorema CAP.
    ]
  ],
  [
    #rect(width: 100%, fill: rgb("#FEF3C7"), inset: 10pt, stroke: 1pt + rgb("#D97706"))[
      #text(weight: "bold", fill: rgb("#B45309"))[Filosofia BASE (Flessibilità)]
      - *Basically Available*: Il sistema garantisce risposte anche in presenza di guasti parziali.
      - *Soft State*: Lo stato delle repliche può evolvere nel tempo anche senza nuovi input.
      - *Eventual Consistency*: Se le scritture cessano, le repliche convergono allo stesso stato.
      *Nota*: BASE è una filosofia pragmatica, non l'opposto logico di ACID.
    ]
  ]
)

== Il Teorema CAP e il Modello PACELC

=== Teorema CAP (Gilbert e Lynch, 2002)
In qualsiasi sistema distribuito con dati replicati soggetto a partizioni di rete (*P*), è impossibile garantire contemporaneamente la consistenza forte (*C* = Linearizzabilità) e la disponibilità (*A* = ogni nodo non guasto risponde con esito non di errore) per ogni richiesta:

$text("Durante una partizione di rete (P):") quad text("Scegli tra") bold(C) text("(Rifiuta/Attendi)") quad text("oppure") quad bold(A) text("(Rispondi con dati potenzialmente obsoleti)")$

=== Formulazione PACELC (Abadi, 2012)
Poiché le partizioni di rete sono eventi rari, il teorema CAP non descrive il comportamento a regime normale. Il modello *PACELC* estende CAP incorporando la latenza:

$bold("If") bold(P) text("artition: choose") (bold(A) ∨ bold(C)); quad bold("Else:") text("choose") (bold(L) text("atency") ∨ bold(C) text("onsistency"))$

Se vi è una partizione, si sceglie tra Availability e Consistency; altrimenti (*Else*), in condizioni di funzionamento normale, si sceglie tra bassa Latency e forte Consistency (dovuta ai messaggi di coordinamento tra repliche).

== Gerarchia dei Modelli di Consistenza

1. *Linearizzabilità (Consistenza Forte)*: Esiste un ordine globale delle operazioni su una singola linea temporale reale. Ogni lettura restituisce l'ultimo valore scritto completato prima dell'invocazione della lettura. Le operazioni appaiono atomiche nel tempo reale.
2. *Consistenza Sequenziale*: Esiste un ordine globale per tutte le operazioni, e le operazioni di ciascun singolo processo appaiono nell'ordine specificato dal suo programma (*program order*). Non richiede il vincolo del tempo reale.
3. *Consistenza Causale*: Le operazioni legate da una relazione di causa-effetto (secondo la relazione *happened-before* di Lamport) devono essere viste nello stesso ordine da tutti i nodi. Scritture concorrenti non causali possono essere viste in ordini diversi.
4. *Garanzie di Sessione (Client-Centric)*:
   - *Read-Your-Writes*: Un client che ha effettuato una scrittura vedrà sempre la sua modifica nelle letture successive.
   - *Monotonic Reads*: Un client che ha letto un determinato valore non vedrà mai in seguito un valore più vecchio.
5. *Consistenza Eventuale*: Garanzia minima che assicura che, in assenza di nuovi aggiornamenti, tutte le repliche convergeranno al medesimo valore finale. Non offre garanzie su cosa restituisca una lettura prima della convergenza.

== Replicazione Senza Conflitti: I CRDTs
I *CRDT* (*Conflict-free Replicated Data Types*, Shapiro et al., 2011) sono strutture dati distribuite concepite per consentire aggiornamenti concorrenti su più repliche senza coordinamento centrale, garantendo la *Strong Eventual Consistency* per costruzione matematico-algebraica.

I CRDT si basano sulle proprietà di un semreticolo superiore (*join-semilattice*): l'operazione di fusione (*merge*) $⊔$ deve essere *commutativa*, *associativa* e *idempotente*:

$x ⊔ y = y ⊔ x quad (text("Commutatività")), (x ⊔ y) ⊔ z = x ⊔ (y ⊔ z) quad (text("Associatività")), x ⊔ x = x quad (text("Idempotenza"))$

#table(
  columns: (1fr, 2fr, 2fr),
  align: (left, left, left),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("#E9ECEF") } else { none },
  [*Tipo di CRDT*], [*Meccanismo di Funzionamento*], [*Casi d'Uso Tipici*],
  [*G-Counter* (Grow-only)], [Ogni replica incrementa unicamente la propria cella in un vettore. Il valore è la somma degli elementi; il merge è il massimo elemento per elemento.], [Contatori di visite, contatori di clip video.],
  [*PN-Counter*], [Mantiene due G-Counter distinti: uno per gli incrementi e uno per i decrementi. Valore = $P - N$.], [Conteggio utenti online, metriche bilanciate.],
  [*OR-Set* (Observed-Remove)], [Associa ad ogni elemento inserito un tag univoco (UUID). La rimozione cancella i tag osservati.], [Carrelli della spesa e liste di desideri concorrenti.],
  [*LWW-Register* (Last-Write-Wins)], [Associa all'aggiornamento un timestamp. Il merge conserva il valore con timestamp maggiore.], [Registri di stato scalari e profili utente.]
)


= Analisi e Comparazione dei Sistemi Distribuiti (Systems)

== Apache Cassandra: Architettura Wide-Column e Consistenza Sintonizzabile
Cassandra è uno store distribuito wide-column basato sui principi di Amazon Dynamo e Google Bigtable:

- *Anello di Token e Hash*: La *partition key* viene sottoposta ad hashing tramite una funzione (es. Murmur3) per generare un token a 128 bit posizionato su un anello. Il token determina le repliche fisiche competenti.
- *Replication Factor (RF)*: Specifica il numero totale di nodi su cui viene copiata ogni partizione.
- *Consistenza Sintonizzabile (Per-Request Consistency)*: Per ogni operazione di lettura o scrittura il client può specificare il livello di consistenza desiderato:
  - `ONE`: Risposta ottenuta dalla prima replica che risponde.
  - `QUORUM`: Risposta ottenuta dalla maggioranza qualificata delle repliche ($floor(text("RF") / 2) + 1$).
  - `ALL`: Risposta ottenuta da tutte le $text("RF")$ repliche.
  - `LOCAL_QUORUM`: Maggioranza all'interno del data center locale (ottimizzato per deployment multi-region).

#callout(title:"Regola del Quorum di Cassandra")[
  Affinché ogni operazione di lettura intercetti sicuramente l'ultima scrittura completata, la somma del livello di scrittura $W$ e di lettura $R$ deve superare strettamente il Replication Factor $N$:
  $R + W > N$
  Se $N=3$, impostando $W=text("QUORUM") (2)$ ed $R=text("QUORUM") (2)$, si ha $2 + 2 = 4 > 3$, garantendo l'intersezione non vuota tra il set di scrittura e il set di lettura.
]

== MongoDB: Document Store e Replica Sets
MongoDB memorizza i dati sotto forma di documenti BSON organizzati in collezioni:

- *Replica Set*: Architettura leader-based composta da un nodo *Primary* (che gestisce tutte le scritture registrandole in un *oplog*) e molteplici nodi *Secondaries* che replicano l'oplog in modo asincrono. Se il Primary crasha, si avvia un'elezione automatica Raft-like.
- *Sharded Cluster*: Distribuisce le collezioni su più replica sets (*shards*) coordinati da server di configurazione e dai router `mongos`.
- *Livelli di Garanzia*:
  - *Write Concern*: Specifica quanti membri devono confermare la scrittura prima della risposta (es. `w: 1`, `w: "majority"`).
  - *Read Concern*: Specifica la freschezza dei dati letti (es. `"local"`, `"majority"`, `"linearizable"`).
  - *Read Preference*: Indirizza le letture verso il Primary o i Secondaries (`primary`, `secondary`, `nearest`).

== Redis: In-Memory Access, Pub/Sub e Streams
Redis è uno store in-memory ad altissime prestazioni che supporta strutture dati complesse (stringhe, liste, set, hash, zset, streams):

- *Replicazione*: Di default asincrona dal primario alle repliche. In caso di failover, gli aggiornamenti confermati ma non ancora propagati possono andare perduti.
- *Pub/Sub Channels*: Pattern *fire-and-forget* senza persistenza. I messaggi pubblicati in assenza di iscritto vanno persi.
- *Redis Streams*: Log append-only persistente basato su ID temporali con supporto a *Consumer Groups*, riscontri (*ACK*) e recupero di messaggi pendenti, concettualmente analogo ad Apache Kafka.

== Neo4j: Property Graph e le Sfide del Partizionamento
Neo4j è il principale database a grafo nativo:

- *Property Graph Model*: Nodi connessi da relazioni orientate e dotati di proprietà chiave-valore.
- *Linguaggio Cypher*: Consente di formulare query dichiarative basate su pattern matching per attraversare le relazioni (`MATCH (p:Person)-[:BOUGHT]->(i:Item) RETURN p`).
- *Sfida del Partizionamento*: I grafi sono noti per essere estremamente difficili da partizionare tra nodi diversi (*graph partitioning problem*), poiché gli attraversamenti multi-hop rischiano di incrociare continuamente i confini di rete tra shards.

== Apache HBase: Progettazione Log-Structured (LSM-Tree)
HBase è uno store wide-column basato su HDFS, con consistenza forte per riga:

- *Percorso di Scrittura (Write Path)*:
  $text("Client") → text("RegionServer") → text("WAL (Write-Ahead Log on HDFS)") → text("MemStore (In-Memory Buffer)") → text("HFiles (Immutable Sorted on Disk)")$
- *Log-Structured Merge-Tree (LSM-Tree)*: Le scritture sono sempre append-only sequenziali veloci in memoria e su WAL; periodicamente le tabelle in memoria vengono scaricate su disco come file immutabili (*HFiles*) soggetti a fasi di compattazione (*Compaction*). È il medesimo principio condiviso da Cassandra e RocksDB.

== Distributed SQL: La Falsa Dicotomia
I sistemi *Distributed SQL* (come *Google Spanner*, *CockroachDB* e *YugabyteDB*) superano la storica dicotomia tra database relazionali tradizionali e NoSQL:

- *Cosa rimane Relazionale*: Modello dei dati a tabelle, query SQL espressive e transazioni ACID rigide.
- *Cosa diventa Distribuito*: Lo storage sottostante è partizionato e replicato tramite algoritmi di consenso distribuito (*Paxos* o *Raft*).
- *Il Meccanismo di Spanner*: Google Spanner sfrutta la tecnologia *TrueTime* (orologi atomici e GPS nei data center) per assegnare timestamp assoluti con incertezza limitata $ε$, garantendo transazioni ACID distribuite su scala globale con consistenza serializzabile.

== Matrice Comparativa dei Sistemi
La tabella seguente riassume la comparazione sistematica tra le tecnologie esaminate nella Lezione 07:

#table(
  columns: (1fr, 1.1fr, 1.2fr, 2fr),
  align: (left, left, left, left),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("#E9ECEF") } else { none },
  [*Sistema*], [*Modello Prevalente*], [*Architettura Replicazione*], [*Punto Chiave dell'Ingegneria Software*],
  [*Cassandra*], [Wide-column], [Leaderless (Dynamo)], [Replication factor ed equazione del quorum $R+W > N$.],
  [*MongoDB*], [Documento], [Leader-based (Replica Set)], [Configurazione granulare di Write/Read Concern.],
  [*Redis*], [Key-value (In-memory)], [Leader-based Asincrono], [Prestazioni estreme; il cache non è la sorgente primaria.],
  [*Neo4j*], [Property Graph], [Cluster Leader-based], [Eccelle nelle query multi-hop; sfide di sharding.],
  [*HBase*], [Wide-column su HDFS], [Storage-level (HDFS)], [Write path Log-Structured (LSM-Tree); consistenza forte per riga.],
  [*Spanner / CockroachDB*], [Relazionale Distribuito], [Consenso Raft/Paxos per Shard], [Transazioni ACID distribuite scalabili al costo della latenza di consenso.]
)


= Pratica di Progettazione ed Esercizi Guidati (Design Practice)

== Case Study: Il Global Shop E-Commerce
Nella quinta parte della lezione, si analizza l'architettura di dati per una piattaforma e-commerce globale (*The Global Shop*). Un singolo database non soddisfa in modo ottimale tutti i carichi di lavoro; occorre applicare la *Persistenza Poliglotta* delegando i moduli a store specifici:

#table(
  columns: (1fr, 1.5fr, 1.5fr, 1.8fr),
  align: (left, left, left, left),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("#E9ECEF") } else { none },
  [*Modulo Dati*], [*Store Consigliato*], [*Garanzia Fondamentale*], [*Compromesso / Debolezza Accettabile*],
  [*Catalogo Prodotti*], [Document Store + Search Index + Cache], [Attributi flessibili e letture indicizzate a bassa latenza.], [Letture stabili/obsolete per alcuni secondi (stale reads).],
  [*Carrello della Spesa*], [Key-Value / Document / CRDT Set], [Garanzia *Read-Your-Writes* per la sessione utente.], [Fusione di modifiche concorrenti da dispositivi diversi.],
  [*Inventario e Stock*], [Store Transazionale / Conditional Updates], [Invariante di dominio rigoroso: $"stock" ≥ 0$ (no overselling).], [Rifiuto delle vendite nel lato di minoranza durante partizioni.],
  [*Ordini e Pagamenti*], [Distributed SQL (Spanner / Cockroach)], [Atomicità e Durabilità ACID transazionale.], [Latenza di scrittura superiore per via del consenso tra data center.]
)

== Risoluzione Guidata dell'Esercizio 1: Partizioni e Quorum
*Testo del problema*: Si considera un cluster con $N = 3$ repliche. Una scrittura viene eseguita con $W = text("QUORUM")$ (richiede $2$ conferme) ed ha esito positivo. Successivamente, una replica diviene irraggiungibile a causa di una partizione di rete.

#callout(title:"Svolgimento e Soluzione dell'Esercizio 1")[
  1. *Una lettura con $R = text("QUORUM")$ può completarsi? Quali repliche rispondono?* \
     *Risposta*: Sì, la lettura si completa con successo. Poiché restano $2$ repliche raggiungibili su $3$, vi sono nodi sufficienti per formare il quorum ($R = 2$). Risponderanno le due repliche sopravvissute nel lato di maggioranza.
  2. *Cosa può accadere con letture con $R = text("ONE")$ dopo una scrittura che ha raggiunto una sola replica (scrittura fallita)?* \
     *Risposta*: Se la scrittura precedente è fallita o parziale ed ha aggiornato solo $1$ replica, un client che effettua una lettura con $R = text("ONE")$ potrebbe interpellare una delle $2$ repliche non aggiornate ed ottenere il valore vecchio, oppure interpellare l'unica replica aggiornata ed ottenere il nuovo valore, generando inconsistenze tra client diversi.
  3. *L'equazione $R + W > N$ è sufficiente a garantire la Linearizzabilità?* \
     *Risposta*: No, non è sufficiente da sola. L'intersezione $R + W > N$ garantisce l'intersezione insiemistica tra set di lettura e scrittura, ma per avere la vera linearizzabilità occorrono meccanismi aggiuntivi quali la lettura coordinata dal leader (*leader leases*), la riparazione in lettura immediata (*read repair*) prima di rispondere al client, o la prevenzione del ritorno di valori di scritture non ancora committate definitivamente.
]

== Risoluzione Guidata dell'Esercizio 2: Scelte di Garanzia sotto Partizione
*Scenario*: Una partizione di rete isola l'Europa dall'America per 10 minuti. L'inventario ha 3 repliche in Europa e 2 in America ($N = 5$).

#callout(title:"Svolgimento e Soluzione dell'Esercizio 2")[
  1. *Un cliente in America può sfogliare il catalogo? Con quali dati?* \
     *Risposta*: Sì, il catalogo adotta la disponibilità (*AP*). Il cliente naviga il catalogo letto dalla cache locale o dalle repliche americane, accettando descrizioni e prezzi eventualmente obsoleti di pochi minuti.
  2. *Un cliente in America può aggiungere articoli al carrello? Come vengono riconciliati?* \
     *Risposta*: Sì, il carrello usa la garanzia *Read-Your-Writes* locale o un CRDT (OR-Set). Le modifiche vengono salvate nella replica americana e riordinate automaticamente tramite merge di CRDT al ripristino della connettività con l'Europa.
  3. *Un cliente in America può acquistare l'ultima unità di un prodotto?* \
     *Risposta*: No. L'acquisto dell'ultima unità richiede di garantire l'invariante $"stock" ≥ 0$. Poiché l'America possiede solo 2 repliche su 5, non può raggiungere il quorum di maggioranza ($floor(5/2) + 1 = 3$). L'operazione viene rifiutata restituendo un messaggio di errore o "Servizio temporaneamente non disponibile".
  4. *Quale lato può continuare ad accettare ordini di acquisto definitivi?* \
     *Risposta*: Il lato europeo. L'Europa possiede 3 repliche su 5 e costituisce la maggioranza assoluta (*quorum*), pertanto può continuare ad eseguire transazioni atomicamente sicure garantendo l'invariante di non sovra-vendita.
]


= Sintesi dei Concetti Chiave (Takeaways)

- *Dimensioni Indipendenti*: Modello di dati, meccanismo di distribuzione e garanzie di consistenza sono tre dimensioni architetturali distinte ed ortogonali.
- *Trade-off delle Partizioni*: Durante una partizione di rete, ciascuna operazione deve scegliere se privilegiare la disponibilità (*A*) o la consistenza forte (*C*).
- *Consistenza Guidata dagli Invarianti*: La garanzia di consistenza non deve essere massima per default su tutto il database, ma deve seguire rigorosamente gli invarianti di business dell'applicazione (es. consistenza eventuale per i carrelli, consistenza forte/quorum per lo stock dell'inventario).
- *Principio del Minimo Vincolo*: Scegliere sempre le garanzie di consistenza più deboli sufficienti a preservare la correttezza del sistema, al fine di massimizzare le prestazioni e la tolleranza ai guasti.
