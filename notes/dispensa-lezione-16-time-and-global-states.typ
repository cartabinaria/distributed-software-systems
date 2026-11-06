#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 16",
  subtitle: "Tempo, Orologi Logici e Stati Globali nei Sistemi Distribuiti",
  author: "Alice Benatti",
  accent-color: rgb("#1a9133")
)

= Perché il Tempo è Difficile nei Sistemi Distribuiti

Nei sistemi centralizzati monolitici, la nozione di tempo è univoca e deterministica: quando un processo interroga il sistema operativo per conoscere l'ora, ottiene una lettura definita da un unico orologio hardware centrale. Nei sistemi distribuiti, invece, la presenza di molteplici nodi autonomi interconnessi da canali di rete elimina la possibilità di disporre di un orologio fisico globale perfettamente condiviso ("Time is money" - B. Franklin).

== Ambiguità del Tempo e le Tre Domande Architetturali
Per comprendere l'impatto del tempo nei sistemi distribuiti, occorre analizzare tre problemi pratici fondamentali che un architetto software si trova ad affrontare:

#table(
  columns: (1.2fr, 2fr, 2fr, 1.2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Dominio Applicativo* ], [ *Domanda Ingegneristica* ], [ *Requisito Architetturale* ], [ *Soluzione* ],
  [ *Monitoraggio batterie laptop* ], [ In quale istante esatto è stato misurato ogni livello? ], [ Orologi fisici sincronizzati tra i nodi ], [ Parte 2: Orologi Fisici ],
  [ *Asta distribuita real-time* ], [ Quale offerta (*bid*) è arrivata prima? ], [ Ordinamento causale degli eventi ], [ Parte 3: Tempo Logico ],
  [ *Debugging di sistemi distribuiti* ], [ La differenza $|x_1 - x_2|$ ha mai superato la soglia di 50? ], [ Snapshot di uno stato globale coerente ], [ Parte 4: Stati Globali ]
)

=== L'Esempio Classico del Comando `make`
Consideriamo due calcolatori distinti: la *Macchina A* su cui è in esecuzione l'ambiente di sviluppo (editor) e la *Macchina B* su cui risiede il compilatore.
1. Sulla Macchina B viene creato il file compilato `output.o` all'ora locale `21:44`.
2. SUCCESSIVAMENTE, sulla Macchina A lo sviluppatore modifica il sorgente `output.c` e lo salva all'ora locale `21:43` (poiché l'orologio della Macchina A è sfasato all'indietro di 2 unità).
3. Quando l'utility `make` confronta i timestamp, legge che `output.c` ha un timestamp ($21:43$) *precedente* a `output.o` ($21:44$). Di conseguenza, `make` deduce erroneamente che il codice non necessiti di ricompilazione, lasciando l'eseguibile inconsistente.

== Tre Nozioni di Tempo
Per superare queste ambiguità, formalizziamo tre astrazioni di tempo:

#table(
  columns: (1.2fr, 2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Nozione di Tempo* ], [ *Definizione e Natura* ], [ *Limitazioni e Applicabilità* ],
  [ *Tempo Assoluto (UTC)* ], [ Rappresenta l'orologio ideale di un osservatore esterno con precisione infinita. ], [ *Inrealizzabile in pratica*: la relatività, la latenza di rete e il drift impediscono la sincronizzazione perfetta. ],
  [ *Tempo Locale Fisico* ], [ Ogni nodo legge il proprio orologio hardware basato su oscillatore al quarzo. ], [ *Soggetto a Skew e Drift*: gli orologi locali divergono progressivamente in assenza di resincronizzazione. ],
  [ *Tempo Logico* ], [ Basa l'ordinamento degli eventi sulla relazione di causalità potenziale (*happened-before*). ], [ Svincolato dai clock fisici; permette di ordinare coerentemente gli eventi senza orologi sincronizzati. ]
)

== Skew, Drift e Regole per i Programmatori
Ogni calcolatore misura il tempo mediante un circuito temporizzatore composto da un *cristallo di quarzo* lavorato di precisione e due registri hardware: un *counter* (decrementato ad ogni oscillazione del quarzo) e un *holding register*. Quando il contatore raggiunge lo zero, viene generato un *clock tick* (interruzione hardware) che incrementa il contatore software del tempo in memoria.

- *Clock Skew (Sfasamento)*: La differenza $|C_i(t) - C_j(t)|$ tra le letture di due orologi in uno stesso istante fisico $t$.
- *Clock Drift (Deriva)*: La tendenza degli orologi fisici a misurare il tempo a frequenze leggermente diverse a causa di variazioni di temperatura, tensione elettrica e tolleranze di fabbricazione ($d C / d t eq.not 1$).

Un tipico oscillatore al quarzo presenta un tasso di deriva $rho approx 10^{-6} "s/s"$, pari a circa *31.5 secondi all'anno* (circa 2.6 secondi al mese). Sebbene sembri irrilevante per la vita quotidiana, per un sistema distribuito con milioni di operazioni al secondo causa errori sistematici.

=== Dimostrazione Matematica dell'Intervallo di Resincronizzazione
Se due orologi $C_i$ e $C_j$ hanno tassi di deriva opposti di valore massimo $rho$ rispetto al tempo UTC reale, la velocità relativa con cui divergono è $2rho$. Per garantire una precisione interna $pi$ (ovvero $|C_i(t) - C_j(t)| <= pi$), la resincronizzazione deve avvenire a intervalli temporali $Delta t$ tali che:

$ 2rho dot.c Delta t <= pi -> Delta t <= pi/(2rho) $

#callout(title: "Esempi Intuitivi tratti dalla Lezione", kind: "example")[
- *La carica delle batterie nei laptop*: Chiedere l'esatto livello di carica della batteria di tutti i computer in aula ad un preciso istante fisico è impossibile senza orologi sincronizzati; ciascun nodo risponderà ad un istante sfasato.
- *L'analogia delle elezioni USA*: Il sistema elettorale è un sistema distribuito che registra i voti usando una nozione di tempo molto "rilassata" (voti via mail inviati settimane prima, fusi orari differenti), dimostrando la difficoltà nel definire uno stato globale istantaneo.
- *Time is Money e Riforme del Calendario*: Nel 1582 la riforma gregoriana (promulgata da Papa Gregorio XIII per riallineare l'anno solare) tagliò 10 giorni dal calendario, scatenando proteste commerciali tra locatori e lavoratori sull'incasso degli affitti e dei salari.
]

#callout(title: "Regole Ingegneristiche per la Gestione del Tempo nel Codice", kind: "warning")[
1. *Misurare le durate solo con orologi monotoni*: Utilizzare API come `time.monotonic` in Python o `System.nanoTime()` in Java. I clock di sistema (*wall-clock*) possono subire regolazioni brusche all'indietro.
2. *Mai assumere che il wall-clock muova solo in avanti*: Aggiustamenti NTP o secondi bisestili possono far "tornare indietro" l'ora di sistema.
3. *Non confrontare mai timestamp di macchine diverse senza conoscerne l'incertezza*: Un timestamp $t_A$ da $A$ e $t_B$ da $B$ non sono confrontabili senza considerare il margine d'errore $epsilon$.
]


= Orologi Fisici e Sincronizzazione

== UTC, Secondi Bisestili e Clock Slewing
Il riferimento globale per il tempo civile è il *Coordinated Universal Time (UTC)*, mantenuto da orologi atomici al cesio-133 (9.192.631.770 transizioni atomiche per secondo solare).

=== Leap Seconds e la Tecnica del Leap Smearing
Poiché la rotazione terrestre rallenta in modo irregolare, l'UTC viene regolato introducendo i *secondi bisestili* (*leap seconds*, 23:59:60). Poiché l'introduzione improvvisa di un secondo bisestile ha provocato gravi disservizi software (crash del kernel Linux nel 2012, fallimento di fornitori DNS nel 2017 a causa di codice che assumeva che il tempo non andasse mai indietro), la CGplus.minus nel 2022 ha stabilito l'abolizione dei leap seconds entro il 2035. I grandi gestori Cloud moderni adottano la tecnica del *Leap Smearing*, diluendo la correzione di un secondo nell'arco delle 24 ore mediante una minima variazione della frequenza degli orologi.

=== Requisiti Formali di Sincronizzazione
- *Sincronizzazione Esterna ($alpha$)*: Garantisce che ogni orologio locale $C_i(t)$ differisca dall'ora UTC $t$ di al più $alpha$: $|C_i(t) - t| <= alpha$.
- *Sincronizzazione Interna ($pi$)*: Garantisce che due orologi qualsiasi del sistema non differiscano tra loro di più di $pi$: $|C_i(t) - C_j(t)| <= pi$. Se un sistema ha accuratezza esterna $alpha$, la sua precisione interna è $pi = 2 alpha$.

#callout(title: "Principale Regola di Regolazione degli Orologi (Clock Slewing)", kind: "definition")[
Un orologio locale non deve *mai essere impostato all'indietro* ("craziness" nei log). Se un orologio risulta in avanti di 2 secondi rispetto al riferimento, il software di sincronizzazione rallenta gradualmente il ritmo dei tick hardware (*slewing*), distribuendo il riallineamento senza mai interrompere la monotonicità del tempo.
]

== Algoritmi di Sincronizzazione: Cristian e Berkeley

=== Algoritmo di Cristian (Sincronizzazione Esterna Passiva)
Un client $p$ richiede l'ora a un time server $S$ dotato di ricevitore UTC. $p$ misura il Round-Trip Time ($T = T_4 - T_1$) ed imposta il proprio orologio a:

$ C_p = t_"server" + T/2 $

L'accuratezza ottenuta è pari a $plus.minus (T/2 - T_"min")$, dove $T_"min"$ è il tempo minimo di propagazione unidirezionale di rete.

*Perché l'algoritmo di Cristian seleziona la misurazione con RTT minimo anziché la media?*
Come spiegato a lezione, tra $N$ campionamenti, la misurazione con il Round-Trip Time $T$ *minimo* è quella che ha subito il minor ritardo di accodamento e congestione di rete; fornisce quindi l'approssimazione più precisa al tempo fisico reale di transito.

=== Algoritmo di Berkeley (Sincronizzazione Interna Attiva)
In assenza di una sorgente UTC esterna, un nodo eletto come *Master* interpella periodicamente gli *Slave*:
1. Il Master richiede l'ora a tutti i nodi e stima i loro tempi locali corretti per i relativi RTT.
2. Calcola una *media ponderata tollerante ai guasti*, scartando gli *outliers* la cui differenza supera una soglia predefinita.
3. Invia a ciascun nodo non l'ora assoluta, ma la *correzione relativa* ($plus.minus Delta$) da applicare al proprio orologio.

== Network Time Protocol (NTP) e Precision Time Protocol (PTP)
Il *Network Time Protocol (NTP)* (RFC 5905, definita dall'IETF) organizza i server in una struttura gerarchica ad albero denominata *Strata*:
- *Stratum 0*: Orologi atomici o ricevitori GPS ad alta precisione.
- *Stratum 1*: Server primari direttamente collegati ai dispositivi di Stratum 0.
- *Stratum 2, 3, ...*: Server secondari sincronizzati con lo strato superiore.

NTP scambia coppie di messaggi tra i nodi $A$ e $B$ registrando quattro timestamp ($T_1, T_2, T_3, T_4$). L'offset temporale $theta$ e il ritardo di rete $Delta$ vengono calcolati come:

$ Delta = ((T_4 - T_1) - (T_3 - T_2)) / 2, theta = ((T_2 - T_1) + (T_3 - T_4)) / 2 $

Delle ultime 8 misurazioni $(theta, Delta)$, NTP trattiene la coppia con il valore di ritardo $Delta$ minimo.

=== Oltre NTP: PTP e Google TrueTime
- *PTP (IEEE 1588)*: Utilizza timestamping hardware gestito direttamente dalle schede di rete (NIC) e dagli switch, raggiungendo precisioni inferiori al microsecondo.
- *Google TrueTime (Spanner)*: L'API TrueTime espone esplicitamente l'incertezza temporale tramite l'intervallo $[T_"earliest", T_"latest"]$ con margine d'errore $epsilon approx 6 "ms"$. Nel database Spanner, prima di confermare una transazione (*commit*), il sistema applica la regola *Commit Wait*: attende un tempo pari a $2 epsilon$ garantendo che il timestamp assegnato sia sicuramente passato nel tempo reale globale.


= Tempo Logico e Relazione Happened-Before

Nei sistemi distribuiti asincroni, l'assenza di orologi fisici sincronizzati richiede un meccanismo per ordinare gli eventi basato unicamente sul flusso di informazioni.

== La Relazione Happened-Before di Lamport
Introdotta da Leslie Lamport nel 1978, la relazione *Happened-Before* ($->$) definisce la causalità potenziale tra eventi in un sistema distribuito privo di memoria condivisa.

#callout(title: "Definizione Formale della Relazione Happened-Before (HB)", kind: "definition")[
La relazione $->$ è la più piccola relazione di ordine parziale che soddisfa le tre regole:
1. *HB1 (Sequenzialità Locale)*: Se gli eventi $e$ ed $e'$ appartengono allo stesso processo $p_i$ ed $e$ precede $e'$, allora $e -> e'$.
2. *HB2 (Messaggistica)*: Per qualsiasi messaggio $m$, l'evento di invio $"send"(m)$ precede sempre l'evento di ricezione $"receive"(m)$: $"send"(m) -> "receive"(m)$.
3. *HB3 (Transitività)*: Se $a -> b$ e $b -> c$, allora $a -> c$.
]

=== Eventi Concorrenti
Due eventi $a$ e $b$ si definiscono *concorrenti* ($a || b$) se e solo se non esiste alcuna catena di messaggi che li colleghi in una direzione o nell'altra:

$ a || b <==> (a !-> b) and (b !-> a) $

La concorrenza significa che gli eventi sono *causalmente indipendenti*: l'esito di $a$ non ha potuto influenzare $b$ e viceversa. La concorrenza *non è una relazione transitiva*.

== Orologi Logici di Lamport
Gli *Orologi di Lamport* associano ad ogni evento $e$ un valore intero $L(e)$ mediante un contatore software locale gestito dalle seguenti regole:

- *LC1 (Incremento Locale)*: Prima di eseguire un evento locale o un invio, il processo $p_i$ incrementa il proprio contatore: $L_i := L_i + 1$.
- *LC2a (Timestamp Invio)*: Ogni messaggio $m$ inviato trasporta il timestamp $t = L_i$.
- *LC2b (Aggiornamento Ricezione)*: Alla ricezione di $(m, t)$, il processo $p_j$ aggiorna il proprio contatore: $L_j := max(L_j, t) + 1$.

#callout(title: "Proprietà e Limiti degli Orologi di Lamport", kind: "warning")[
- *Proprietà di Consistenza Causale*: Se $e -> e'$, allora $L(e) < L(e')$.
- *Limiti (Assenza di Causalità Inversa)*: Se $L(a) < L(b)$, *NON possiamo concludere* che $a -> b$. Gli orologi di Lamport *non sono in grado di rilevare la concorrenza* ($a || b$).
- *Ordinamento Totale Arbitrario*: Spezzando i pareggi mediante l'ID del processo (confrontando la coppia $(L(e), i)$), si ottiene un ordine totale coerente con la causalità, impiegato per la mutua esclusione distribuita e il multicast ad ordine totale.
]

== Orologi Vettoriali (Vector Clocks)
Per superare il limite di Lamport ed identificare la concorrenza in modo esatto, si impiegano gli *Orologi Vettoriali*. Ogni processo $p_i$ mantiene un vettore di $N$ interi $"VC"_i$, dove $"VC"_i[i]$ rappresenta il tempo logico locale di $p_i$ e $"VC"_i[j]$ rappresenta la conoscenza che $p_i$ possiede sugli eventi avvenuti presso $p_j$.

=== Algoritmo degli Orologi Vettoriali
1. *VC1*: Inizialmente, $"VC"_i[k] = 0$ per ogni $k in \{1, dots, N\}$.
2. *VC2*: Prima di ogni evento locale o invio, $p_i$ incrementa la propria componente: $"VC"_i[i] := "VC"_i[i] + 1$.
3. *VC3*: $p_i$ include l'intero vettore $"VC"_i$ come timestamp del messaggio $m$.
4. *VC4*: Alla ricezione di $(m, V_m)$, il processo $p_j$ aggiorna il proprio vettore calcolando il massimo componente per componente:
   $ forall k in \{1, dots, N\}, quad "VC"_j[k] := max("VC"_j[k], V_m[k]) $
   successivamente applica la regola VC2 prima di registrare l'evento di ricezione.

=== Confronto tra Vettori
- $V <= V' <==> forall k, V[k] <= V'[k]$
- $V < V' <==> (V <= V') and (V eq.not V')$
- *Proprietà Isomorfa Chiave*: $e -> e' <==> V(e) < V(e')$
- *Rilevamento Concorrenza*: $a || b <==> (V(a) lt.eq.not V(b)) and (V(b) lt.eq.not V(a))$

== Consegna Causale (Causal Multicast) e Hold-Back Queue
Gli orologi vettoriali permettono di implementare il *Causal Multicast*, garantendo che nessun messaggio di risposta (es. "Re: Meeting") venga mostrato a un utente prima del messaggio originario ("Meeting").

Un processo $p_i$ trattiene un messaggio $m$ proveniente da $p_j$ con timestamp $V_m$ in una *hold-back queue* finché non sono soddisfatte entrambe le condizioni:
1. $V_m[j] = "VC"_i[j] + 1$: $m$ è il messaggio successivo atteso da $p_j$.
2. $forall k eq.not j, \, V_m[k] <= "VC"_i[k]$: $p_i$ ha già consegnato tutti i messaggi visti da $p_j$ prima di inviare $m$.

== Hybrid Logical Clocks (HLC)
Gli *Hybrid Logical Clocks (HLC)* combinano il tempo fisico (NTP) con un contatore logico in una struttura a 64 bit. Gli HLC mantengono la proprietà della causalità di Lamport ($e -> e' => "HLC"(e) < "HLC"(e')$) garantendo che il timestamp rimanga sempre prossimo al tempo reale fisicamente osservabile. Sono adottati in motori Distributed SQL come CockroachDB e YugabyteDB.


= Stati Globali, Tagli e l'Algoritmo di Chandy-Lamport

== Il Problema dello Stato Globale e le Sue Applicazioni
Determinare lo stato globale di un sistema distribuito è indispensabile per risolvere problemi fondamentali:
- *Distributed Garbage Collection*: Verificare se non esistono più riferimenti a un oggetto (né nei nodi né nei messaggi in transito).
- *Deadlock Detection*: Verificare la presenza di cicli nel grafo di attesa delle risorse (*waits-for graph*).
- *Termination Detection*: Rilevare se tutti i processi sono inattivi e non vi sono messaggi in transito nei canali (come sottolineato a lezione, la terminazione è impossibile da rilevare senza snapshot in sistemi asincroni).
- *Distributed Debugging*: Verificare se il sistema ha mai attraversato uno stato non valido.

Uno *Stato Globale* è formalmente definito dall'insieme degli stati locali di tutti i processi $S_i$ unitamente allo stato dei canali di comunicazione $C_(i,j)$ (messaggi inviati ma non ancora consegnati).

== Tagli Coerenti (Consistent Cuts)
Un *Taglio* (*Cut*) $C$ è una suddivisione della storia degli eventi del sistema che seleziona un prefisso della sequenza di eventi per ciascun processo.

#callout(title: "Definizione Formale di Taglio Coerente (Consistent Cut)", kind: "definition")[
Un taglio $C$ si definisce *Coerente* se e solo se è chiuso rispetto alla relazione *happened-before*:
$ forall e in C, quad "se" e' -> e => e' in C $
*Significato fisico*: Un taglio coerente rappresenta uno stato globale che *avrebbe potuto essere osservato* da un osservatore esterno. *Un taglio coerente non contiene mai l'evento di ricezione di un messaggio senza contenerne il relativo evento di invio.*
]

== Algoritmo di Snapshot Distribuito di Chandy-Lamport
L'algoritmo di *Chandy-Lamport* (1985) registra uno stato globale coerente del sistema *mentre le applicazioni continuano la regolare esecuzione*, senza sospendere le attività.

=== Assunzioni
1. Assenza di guasti: i messaggi vengono consegnati intatti ed esattamente una volta.
2. I canali di comunicazione sono unidirezionali e rispettano l'ordine *FIFO* (es. connessioni TCP).
3. Il grafo della rete è fortemente connesso.

=== Meccanismo dei Messaggi Marker
L'algoritmo impiega un messaggio di controllo speciale denominato *Marker*, che separa i messaggi trasmessi prima dell'avvio dello snapshot da quelli trasmessi dopo.

#table(
  columns: (1.5fr, 3.5fr),
  fill: (x, y) => if y == 0 { rgb("#f0fdf4") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Regola Marker* ], [ *Algoritmo ed Esecuzione* ],
  [ *Regola di Invio per $p_i$* ], [ Dopo che $p_i$ ha registrato il proprio stato locale, invia un *Marker* su ciascun canale in uscita *prima* di trasmettere qualsiasi altro messaggio di rete. ],
  [ *Regola di Ricezione per $p_i$ su canale $c$* ], [
    *Caso A (Primo Marker visto da $p_i$)*: $p_i$ salva immediatamente il proprio stato locale; registra lo stato del canale $c$ come *vuoto*; avvia la registrazione dei messaggi in arrivo su tutti gli altri canali in ingresso.\\
    *Caso B ($p_i$ ha già salvato il proprio stato)*: $p_i$ interrompe la registrazione sul canale $c$; lo stato del canale $c$ equivale alla sequenza di messaggi ricevuti su $c$ dal momento in cui $p_i$ aveva salvato il proprio stato locale.
  ]
)

=== Applicazione Industriale: Apache Flink
- *Apache Flink*: Utilizza i *barrier snapshots* (una variante di Chandy-Lamport per dataflow aciclici) per effettuare checkpointing continuo e garantire la semantica *exactly-once* nell'elaborazione di stream massivi.

== Predicati di Stato Globale: Safety, Liveness, Possibly e Definitely
Per analizzare le proprietà di un sistema si valutano i *predicati di stato globale* $phi$:
- *Safety*: Un insieme di stati indesiderati è falso in ogni stato raggiungibile ("*Niente di male accade mai*").
- *Liveness*: Una condizione desiderata diventa vera in ogni sequenza di esecuzione ("*Qualcosa di buono prima o poi accade*").
- *Predicati Stabili*: Predicati che, una volta diventati veri, rimangono veri per sempre (es. *deadlock*, *terminazione*, *garbage*). Un singolo snapshot di Chandy-Lamport è sufficiente a rilevare predicati stabili.
- *Predicati Non Stabili*:
  - *Possibly $phi$*: Esiste almeno una linearizzazione valida dei tagli coerenti che passa per uno stato in cui $phi$ è vero.
  - *Definitely $phi$*: Tutte le linearizzazioni valide dei tagli coerenti attraversano uno stato in cui $phi$ è vero. La verifica richiede la costruzione del *reticolo dei tagli coerenti* (*lattice of global states*), che presenta una complessità esponenziale nel numero di nodi.


= Esercizi Pratici Svolti

== Esercizio: Calcolo dell'Accuratezza con Algoritmo di Cristian
Un client si sincronizza con un time server UTC registrando i seguenti valori:

#table(
  columns: (1.5fr, 2fr, 2.5fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Tentativo* ], [ *Round Trip Time ($T$)* ], [ *Timestamp del Server ($t$)* ],
  [ Tentativo 1 ], [ 22 ms ], [ 10:54:23.674 ],
  [ Tentativo 2 ], [ 25 ms ], [ 10:54:25.450 ],
  [ Tentativo 3 ], [ *20 ms* ], [ *10:54:28.342* ]
)

1. *Quale misurazione utilizzare?*
   Si seleziona il tentativo con il RTT minimo ($T = 20" ms"$), in quanto minimizza il ritardo di congestione della rete.
2. *A quale orario impostare il clock locale?*
   $ C_"new" = t + T/2 = 10:54:28.342 +  10 " ms" = bold(10:54:28.352) $
3. *Qual è l'accuratezza rispetto al server?*
   Assumendo $T_"min" = 0" ms"$, l'incertezza è $plus.minus (T/2) = bold(plus.minus 10" ms")$.
4. *Come cambia l'accuratezza se ogni messaggio richiede un tempo di rete minimo noto $T_"min" = 8 " ms"$?*
   L'ora impostata rimane invariata (10:54:28.352), ma l'accuratezza migliora:
  $ "Incertezza" = plus.minus (T / 2 - T_"min") = plus.minus (10 - 8) = bold(plus.minus 2 "ms") $

== Esercizio: Calcolo Completo di Timestamp di Lamport e Vettoriali
Sia data l'esecuzione a 3 processi descritta in figura (events $a, b, c$ su $p_1$; $d, e$ su $p_2$; $f, g, h$ su $p_3$), con messaggi $m_1: b -> d$, $m_3: g -> c$, $m_2: e -> h$:

#table(
  columns: (1fr, 2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Evento* ], [ *Timestamp di Lamport $L(e)$* ], [ *Timestamp Vettoriale $"VC"(e)$* ],
  [ $a$ ], [ 1 ], [ (1, 0, 0) ],
  [ $b$ ], [ 2 ], [ (2, 0, 0) ],
  [ $f$ ], [ 1 ], [ (0, 0, 1) ],
  [ $g$ ], [ 2 ], [ (0, 0, 2) ],
  [ $d$ (ricezione $m_1$) ], [ $max(0, 2) + 1 = bold(3)$ ], [ *(2, 1, 0)* ],
  [ $e$ ], [ 4 ], [ (2, 2, 0) ],
  [ $c$ (ricezione $m_3$) ], [ $max(2, 2) + 1 = bold(3)$ ], [ *(3, 0, 3)* ],
  [ $h$ (ricezione $m_2$) ], [ $max(2, 4) + 1 = bold(5)$ ], [ *(2, 2, 3)* ]
)

=== Domande di Verifica:
1. *Coppie di eventi concorrenti*: $(g, d)$ in quanto $"VC"(g) = (0,0,2)$ e $"VC"(d) = (2,1,0)$ sono incalcolabili (nessuno è $<=$ dell'altro). Analogamente $(f, a)$ e $(c, e)$.
2. *Coppia con $L(e) < L(e')$ ma concorrenti*: Per l'evento $g$ si ha $L(g) = 2$, per l'evento $d$ si ha $L(d) = 3$. Benché $L(g) < L(d)$, essi sono *concorrenti* ($g || d$), dimostrando che gli orologi di Lamport non possono rilevare la concorrenza.
