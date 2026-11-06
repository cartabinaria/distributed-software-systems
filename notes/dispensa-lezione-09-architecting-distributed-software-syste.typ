#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 09",
  subtitle: "Architecting Distributed Software Systems: Stili, Decisioni e Trade-off",
)

= Che cos'è l'Architettura Software  

Dopo aver analizzato nei capitoli precedenti i meccanismi di basso e medio livello - canali di comunicazione (Lezioni 5 e 6), gestione distribuita dei dati (Lezione 7) ed endpoint persistenti con daemon e oggetti distribuiti (Lezione 8) - la Lezione 9 affronta il livello superiore di astrazione: *come comporre questi meccanismi in sistemi complessi e come motivare le scelte progettuali*.

#callout(title: "Perché l'Architettura? Domande a cui il Codice Sorgente non risponde", kind: "definition")[
Analizzando semplicemente il codice sorgente di un singolo modulo non è possibile rispondere a domande fondamentali sul comportamento globale:
1. *Scalabilità e Prestazioni*: Il sistema escala sotto carico massivo? Qual è il tempo di risposta al novantanovesimo percentile ($p 99$)?
2. *Resilienza e Tolleranza ai Guasti*: Cosa accade quando un componente o un'intera zona di disponibilità fallisce?
3. *Evolvibilità e Deployability*: Con quale facilità il sistema accetta modifiche? Con quale frequenza è possibile rilasciare in produzione senza causare disservizi?
4. *Costi Operativi*: Quanto costa eseguire e far evolvere l'infrastruttura nel tempo?

Le risposte a queste domande dipendono direttamente dall'architettura software scelta.
]

== Definizioni Formali e le Due Leggi Fondamentali

L'architettura software viene formalizzata da diversi standard e autori di riferimento:
- *ISO/IEC/IEEE 42010:2022*: Concetti o proprietà fondamentali di un sistema nel suo ambiente, incarnati nei suoi elementi, nelle sue relazioni e nei principi che ne guidano la progettazione e l'evoluzione.
- *Bass, Clements, Kazman (SEI)*: Le strutture software necessarie per ragionare sul sistema, comprendenti elementi software, relazioni tra di essi e proprietà di entrambi.
- *Richards & Ford (2025)*: $text("Architettura") = text("Struttura (Stile)") + text("Caratteristiche") + text("Decisioni") + text("Principi")$.

Dalla riflessione teorica ed empirica derivano le *Due Leggi Fondamentali dell'Architettura Software*:

1. *Prima Legge dell'Architettura Software*: _Tutto nell'architettura software è un trade-off_ (un compromesso). Non esistono soluzioni perfette in assoluto, ma solo combinazioni di vantaggi e svantaggi da valutare nel contesto.
2. *Seconda Legge dell'Architettura Software*: _Il "perché" (why) è più importante del "come" (how)_. Documentare le motivazioni e le opzioni scartate è più prezioso che descrivere il solo stato finale.

== Caratteristiche Architetturali (I Requisiti Non Funzionali)

Le caratteristiche architetturali rappresentano i requisiti di sistema che non riguardano direttamente la logica di dominio (le funzionalità), ma le qualità operative e strutturali del sistema. Si articolano in tre gruppi principali:

#table(
  columns: (1.5fr, 3.5fr),
  fill: (x, y) => if y == 0 { rgb("#fee2e2") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Gruppo di Caratteristiche* ], [ *Caratteristiche Specifiche* ],
  [ *Operative (Operational)* ], [ Availability (Disponibilità), Performance, Scalability (Scalabilità), Elasticity (Elasticità), Reliability (Affidabilità), Recoverability. ],
  [ *Strutturali (Structural)* ], [ Modularity (Modularità), Testability (Testabilità), Deployability, Maintainability (Manutenibilità), Extensibility. ],
  [ *Trasversali (Cross-cutting)* ], [ Security (Sicurezza), Observability (Osservabilità), Privacy, Accessibility, Cost (Costo operativo e di licenza). ]
)

#callout(title: "Principio di Misurabilità", kind: "warning")[
È materialmente impossibile massimizzare contemporaneamente tutte le caratteristiche architetturali. Il compito dell'architetto consiste nell'individuare le pochissime caratteristiche critiche per il dominio di business e renderle rigorosamente misurabili (ad esempio tramite SLO/SLA e *fitness functions*).
]

== Stili, Pattern e Viste Architetturali

È essenziale distinguere tre livelli di astrazione:
- *Stile Architetturale (Architecture Style)*: La forma complessiva e l'organizzazione strutturale di un sistema (es. Layered, Event-Driven, Microservices, Space-Based).
- *Pattern Architetturale*: Una soluzione riutilizzabile a un problema ricorrente in un determinato contesto (es. Façade, Circuit Breaker, Saga, API Gateway).
- *Architettura di Riferimento (Reference Architecture)*: Istanziazione di pattern e stili in un dominio specifico (es. AWS Well-Architected Framework, Azure Architecture Center).

=== Descrivere l'Architettura tramite Viste: Il Modello C4
Poiché un singolo diagramma non è mai sufficiente per rappresentare un sistema complesso, si utilizzano modelli a più viste. Oltre al classico modello *4+1 di Kruchten* (1995), lo standard moderno de facto per i sistemi distribuiti è il *Modello C4 di Simon Brown*, articolato in quattro livelli di zoom progressivo:

1. *Level 1 - System Context*: Mostra il sistema distribuito come un unico blocco al centro, identificando gli utenti umani e i sistemi esterni confinanti.
2. *Level 2 - Containers*: Zoom all'interno del sistema per mostrare le unità indipendentemente deployabili (applicazioni web, API Gateway, microservizi, database, broker di messaggi).
3. *Level 3 - Components*: Zoom all'interno di un singolo container per mostrare i moduli software interni e le loro interazioni.
4. *Level 4 - Code*: Rappresentazione di dettagli implementativi (classi, interfacce, funzioni) tramite diagrammi UML o codice.

== La Legge di Conway e la Struttura dei Team

Nel 1968, Melvin Conway formulò la celebre legge sociotecnica:
_"Le organizzazioni che progettano sistemi sono vincolate a produrre disegni che sono copie delle strutture di comunicazione dell'organizzazione stessa."_

- Se un'azienda organizza il team di sviluppo in tre gruppi isolati (team UI, team Backend, team DBA), la legge di Conway dimostra che l'architettura risultante sarà inevitabilmente un *sistema a 3 livelli (Layered Architecture)* rispecchiante i tre team.
- *Manovra di Conway Inversa (Inverse Conway Manoeuvre)*: Consiste nel modellare intenzionalmente la struttura dei team di sviluppo in base all'architettura desiderata (es. team multidisciplinari autonomi organizzati per *business capability* per ottenere microservizi disaccoppiati, come teorizzato in *Team Topologies* di Skelton & Pais).

=  Architetture Stratificate: Layers e Tiers

==  Distinzione Formale tra Layer e Tier

Uno degli errori concettuali più frequenti consiste nel confondere *Layers* e *Tiers*:

#callout(title: "Layers vs. Tiers: La metafora dell'Cipolla e dell'Aglio", kind: "definition")[
- *Layer (Livello Logico)*: Un raggruppamento logico di funzionalità per livello di astrazione. Un layer usa unicamente i livelli sottostanti.
- *Tier / Partition (Partizione Fisica)*: Unità di deployment fisica o di processo (macchina, container, nodo).
- *Regola*: _I Layers raggruppano le funzionalità dal punto vista logico; i Tiers le allocano fisicamente sulla rete._ Si applica la metafora: la cipolla rappresenta i layers (strati concentrici logici), mentre l'aglio rappresenta i tiers (spicchi fisici separati).
]

==  Closed Layers vs. Open Layers

All'interno di uno stile stratificato, la relazione tra livelli può essere:
- *Closed Layers (Livelli Chiusi)*: Il livello $i$ può invocare esclusivamente il livello immediatamente sottostante $i-1$. Garantisce la massima manutenibilità, isolamento delle modifiche e portabilità (es. la pila dei protocolli di rete Internet dove TCP al L4 usa esclusivamente IP al L3).
- *Open Layers (Livelli Aperti)*: Il livello $i$ può bypassare il livello sottostante ed invocare qualsiasi livello inferiore (es. un'applicazione che bypassa lo strato ORM per eseguire direttamente una query SQL ad altissime prestazioni sul database).
- *Sistemi Misti*: La maggior parte dei sistemi reali adotta livelli chiusi per default, consentendo eccezioni esplicite e documentate per ragioni di efficienza.

==  Lo Stile Layered e l'Anti-Pattern Sinkhole

Lo stile *Layered* classico suddivide la logica aziendale in quattro strati tecnici standard:
1. *Presentation Layer* (Interfaccia utente / Controller Web)
2. *Business Layer* (Logica di dominio e regole di business)
3. *Persistence Layer* (Astrazione dell'accesso ai dati / ORM)
4. *Database Layer* (Database fisico)

- *Vantaggi*: Semplicità, basso costo iniziale, struttura familiar e testabilità isolata.
- *Svantaggi*: Ogni nuova funzionalità tende ad impattare tutti i livelli; l'intero sistema costituisce un'unica unità di deployment monolitica.
- *Sinkhole Anti-Pattern*: Si verifica quando le richieste attraversano molteplici livelli senza subire alcuna trasformazione o logica di calcolo, agendo da mero passacarte ("pass-through"). *Regola del 20%*: Se oltre il 20% delle richieste nel sistema presenta un comportamento da Sinkhole, occorre rendere aperti alcuni livelli o rivedere l'architettura.

== Pattern Façade e Architettura Esagonale (Clean Architecture)

- *Pattern Façade*: Un oggetto o classe che offre un'interfaccia semplificata di alto livello a un insieme complesso di classi di un sottosistema. L'interfaccia pubblica di un layer è tipicamente una Façade. Nel contesto distribuito, la versione ad alta scala della Façade è rappresentata dall'*API Gateway*.
- *Architettura Esagonale (Ports and Adapters - Alistair Cockburn 2005 / Clean Architecture - R. C. Martin 2017)*:
  - Il *Dominio aziendale* risiede al centro perfetto e definisce le *Ports* (interfacce astratte).
  - Gli *Adapters* esterni implementano le porte verso l'esterno (Web adapter, DB adapter, Broker adapter, Test adapter).
  - *Dependency Rule*: Tutte le dipendenze del codice puntano rigorosamente verso l'interno, rendendo il database e la rete dettagli sostituibili senza impattare la logica aziendale.


= Pipeline, Plug-in ed Architetture Event-Driven

== Pipeline Architecture (Pipes and Filters)

I dati fluiscono in modo sequenziale attraverso trasformatori denominati *Filters*, collegati tra loro da canali denominati *Pipes*:
$$text("Producer") longrightarrow text("Transformer") longrightarrow text("Tester") longrightarrow text("Consumer") $$
- *Esempi*: Pipeline di comandi Unix (`cat access.log | grep ERROR | sort | uniq -c`), compilatori, processi ETL, elaborazione di flussi di dati e pipeline di inferenza per modelli LLM.
- *Punti di forza*: Elevata riutilizzabilità, semplicità e parallelizzabilità sui singoli filtri.
- *Punti di debolezza*: Inadatto per interazioni bidirezionali complesse e gestione articolata degli errori a metà flusso.

== Microkernel Architecture (Plug-in)

L'architettura *Microkernel* separa un sistema *Core* minimale da un insieme di componenti *Plug-in* indipendenti:
- Il sistema Core contiene la logica essenziale e il registro per i plug-in.
- I plug-in estendono le funzionalità aggiungendo capacità specializzate attraverso un contratto di interfaccia rigido.
- *Esempi*: VS Code, Eclipse, browser web, motori di regole assicurative o fiscali per nazione.
- *Punti di forza*: Estremamente estensibile e modulare.
- *Punti di debolezza*: La modifica del contratto dell'interfaccia del Core risulta estremamente difficile dopo la diffusione dei plug-in.

== Event-Driven Architecture (EDA) e Tipologie di Eventi

Nelle architetture *Event-Driven*, i componenti reattivi rispondono in modo asincrono al verificarsi di *eventi* (cambiamenti significativi di stato) veicolati attraverso broker di messaggi o event log (es. Apache Kafka):

#callout(title: "Cosa trasporta un Evento? I 4 Pattern di Martin Fowler (2017)", kind: "definition")[
1. *Event Notification*: L'evento notifica unicamente che qualcosa è accaduto (payload minimo, es. `{"orderId": 102, "status": "PLACED"}`). Minimo accoppiamento sui dati, ma i consumatori devono effettuare chiamate di callback al produttore per recuperare i dettagli.
2. *Event-Carried State Transfer*: L'evento contiene tutti i dati necessari ai consumatori per completare l'elaborazione senza dover ricontattare il produttore. Elimina le chiamate di callback aumentando la disponibilità, al prezzo di duplicazione dei dati e consistenza eventuale (*eventual consistency*).
3. *Event Sourcing*: Ogni modifica di stato viene registrata come un evento immutabile in un log sequenziale. Il log degli eventi costituisce l'unica fonte di verità (*single source of truth*), consentendo audit completi e riproducibilità temporale dello stato.
4. *CQRS (Command Query Responsibility Segregation)*: Separazione netta tra il modello di scrittura (Comandi) e il modello di lettura (Query), consentendo di scalare ed ottimizzare i due flussi in modo indipendente.
]

== Topologie EDA: Coreografia vs. Orchestrazione

#table(
  columns: (1.2fr, 2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Dimensione* ], [ *Broker Topology (Coreografia)* ], [ *Mediator Topology (Orchestrazione)* ],
  [ *Controllo* ], [ Distribuito: il flusso emerge dalle reazioni a catena dei singoli processori. ], [ Centralizzato: un *Mediator* (Workflow Engine) dirige i passaggi nell'ordine stabilito. ],
  [ *Accoppiamento* ], [ Molto basso: i processori pubblicano ed ascoltano solo eventi dal broker. ], [ Più alto: i componenti comunicano ed eseguono i comandi del Mediator. ],
  [ *Visibilità Flusso* ], [ Difficile: non esiste un punto unico che conosca lo stato globale dell'ordine. ], [ Facile: il Mediator mantiene lo stato aggiornato dell'intera transazione. ],
  [ *Gestione Errori* ], [ Demandata ai singoli processori reattivi. ], [ Gestita centralmente dal Mediator tramite logiche di compensazione. ],
  [ *Scelta Elettiva* ], [ Passaggi indipendenti, volumi massivi e necessità di scalabilità estrema. ], [ Flussi con sequenze rigide, transazioni distribuite e compensazioni complesse. ]
)

#callout(title: "Ingegneria delle Trappole in Event-Driven Architecture", kind: "warning")[
I quattro rischi principali dei sistemi event-driven e i relativi rimedi:
1. *Ordering*: Messaggi ricevuti fuori ordine $->$ Partizionamento per chiave (*partition key*) nel broker e tolleranza al riordinamento.
2. *Duplicates*: Messaggi duplicati dalla rete $->$ Consumatori idempotenti tramite memorizzazione degli identificatori di evento (Event IDs).
3. *Schema Evolution*: Un nuovo produttore corrompe i vecchi consumatori $->$ Gestione degli schemi versionati tramite *Schema Registry*.
4. *Observability*: Impossibilità di tracciare una richiesta end-to-end $->$ Iniezione di *Correlation IDs* e contesti di tracciamento distribuito (W3C Trace Context / OpenTelemetry).
]


= Dal Monolito ai Sistemi Distribuiti: Lo Spettro e l'Architecture Quantum

== Lo Spettro Architetturale

La transizione da un sistema monolitico a uno distribuito non è un'alternativa binaria, ma uno spettro continuo:

```
[ Monolith ] ───► [ Modular Monolith ] ───► [ Service-Based ] ───► [ Microservices ]
  (1 unità)           (1 unità, per domini)     (pochi servizi, DB condiviso)  (molti servizi, DB isolato)
```

Spostarsi verso destra acquista *indipendenza di deployment e scalabilità*, ma paga il prezzo in termini di *chiamate di rete, complessità operativa e consistenza eventuale* (le 8 fallacie della computazione distribuita della Lezione 3).

== Il Monolito Modulare (Modular Monolith)

Il *Monolito Modulare* rappresenta un'unica unità di deployment il cui codice interno è rigorosamente partizionato per domini di business:
- Ogni modulo espone un'API pubblica (Façade), nasconde i dettagli interni e gestisce le proprie tabelle sul database.
- I confini tra i moduli sono verificati automaticamente tramite strumenti di test e compilazione (es. Java Modules, ArchUnit, Spring Modulith, Packwerk).
- *Vantaggio*: Offre la maggior parte dei benefici dei microservizi (isolamento dei domini e chiarezza architetturale) senza pagare alcun costo di rete o di gestione distribuita, garantendo una linea di migrazione pulita per un eventuale futuro *split*.

== L'Architecture Quantum e il Monolito Distribuito

#callout(title: "Definizione di Architecture Quantum", kind: "definition")[
Un *Architecture Quantum* è una porzione di sistema indipendentemente deployabile, comprendente tutte le componenti funzionali, il codice e i dati necessari per funzionare in modo autonomo.
- Servizi che condividono lo stesso schema di database o che devono essere rilasciati obbligatoriamente insieme costituiscono un *unico Architecture Quantum*.
- Le caratteristiche architetturali vengono decise ed applicate a livello di singolo quantum.
]

- *Quando dividere (Split)*: Quando componenti differenti richiedono requisiti opposti di scalabilità, disponibilità, frequenza di deployment, sicurezza o isolamento dai guasti.
- *Quando unire (Join)*: Quando componenti necessitano di transazioni ACID condivise, dati strettamente accoppiati o comunicazioni ad altissima frequenza.
- *Anti-Pattern: Il Monolito Distribuito (Distributed Monolith)*: Si verifica quando un sistema viene suddiviso in decine di microservizi trasmettendo le richieste sulla rete, ma mantenendo un unico database condiviso, deployment sincroni coordinati e chiamate bloccanti a cascata. Rappresenta un singolo Architecture Quantum erroneamente distribuito sulla rete, sommando gli svantaggi del monolito a quelli dei sistemi distribuiti.

== Space-Based Architecture

Progettata per gestire carichi estremi ed imprevedibili (flash sales, aste online, piattaforme di biglietteria per concerti):
- Elimina il database centrale come punto di strozzatura sincrono per le letture e le scritture.
- Si compone di *Processing Units* replicate contenenti sia la logica di calcolo sia un *In-Memory Data Grid* (IMDG).
- Un middleware virtualizzato gestisce la replicazione dello stato tra le Processing Units, mentre appositi *Data Pumps* scrivono gli aggiornamenti sul database centrale in modo asincrono.
- *Eredità storica*: Deriva direttamente dal modello a spazi di tuple di Linda (Lezione 2 e 8) ed è implementata in framework moderni come Hazelcast, Apache Ignite e GigaSpaces.


= Scelta Architetturale, Valutazione e Governance

== Matrice Comparativa degli Stili Architetturali

#table(
  columns: (1.2fr, 1fr, 1.2fr, 1fr, 1.1fr, 1fr, 1fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Caratteristica* ], [ *Layered* ], [ *Modular Monolith* ], [ *Microkernel* ], [ *Event-Driven* ], [ *Microservices* ], [ *Space-Based* ],
  [ *Simplicità* ], [ Alta ], [ Alta ], [ Alta ], [ Bassa ], [ Bassa ], [ Bassa ],
  [ *Costo Ridotto* ], [ Alto ], [ Alto ], [ Alto ], [ Medio ], [ Basso ], [ Basso ],
  [ *Deployability* ], [ Bassa ], [ Media ], [ Media ], [ Alta ], [ Alta ], [ Media ],
  [ *Testabilità* ], [ Media ], [ Alta ], [ Alta ], [ Bassa ], [ Alta ], [ Bassa ],
  [ *Scalabilità* ], [ Bassa ], [ Bassa ], [ Bassa ], [ Alta ], [ Alta ], [ Alta ],
  [ *Elasticità* ], [ Bassa ], [ Bassa ], [ Bassa ], [ Alta ], [ Alta ], [ Alta ],
  [ *Fault Tolerance* ], [ Bassa ], [ Bassa ], [ Bassa ], [ Alta ], [ Alta ], [ Alta ]
)

== Analisi dei Trade-Off e Architecture Decision Records (ADR)

Le decisioni architetturali devono essere documentate in modo strutturato tramite gli *Architecture Decision Records (ADR)* (Michael Nygard 2011), salvati e versionati all'interno del repository del codice sorgente (`docs/adr/0007-....md`).

```markdown
# ADR 0007: Adozione del Monolito Modulare per la Piattaforma E-Commerce

Stato: Accettato (Data: 2026-11-05)

Contesto:
Un unico team di sei sviluppatori gestisce l'applicazione. Si prevedono picchi di carico
durante le vendite stagionali, con budget limitato e dominio in rapida evoluzione.

Decisione:
Adottare un'unica unità di deployment partizionata in moduli di dominio (Catalogo, Ordini,
Pagamenti, Spedizioni) con confini verificati e tabelle dedicate per modulo.

Conseguenze:
Operatività e deployment semplificati; l'intera applicazione escala unitariamente.
Opzioni scartate: Microservizi (troppo complessi ed onerosi per un team di 6 persone).
Condizione di re-valutazione: Se il servizio di Checkout supera di 10 volte il carico medio.
```

== Fitness Functions Architetturali

Le *Fitness Functions* (Ford, Parsons, Kua, Sadalage 2022) rappresentano la traduzione in codice automatizzato delle verifiche sulle caratteristiche architetturali:

- *Strutturali*: Test automatizzati nei job di CI/CD che verificano che i moduli non violino i confini d'accesso o che il dominio non importi framework web (es. tramite ArchUnit o Spring Modulith).
- *Operative*: Check che verificano che la latenza del servizio di Checkout al $p 99$ rimanga inferiore a $200 text(" ms")$ sotto il carico di riferimento.
- *Deployment*: Verifiche che ogni servizio sia integrato tramite test di contratto espliciti.
- *Resilienza*: Simulazioni di chaos engineering che verificano che il sistema sopravviva alla perdita improvvisa di una zona di disponibilità Cloud.

#callout(title: "Sintesi della Governance Architetturale", kind: "success")[
_ADRs + Fitness Functions consentono di passare da un'architettura semplicemente disegnata sulla carta a un'architettura continuamente verificata e governata nel codice._
]
