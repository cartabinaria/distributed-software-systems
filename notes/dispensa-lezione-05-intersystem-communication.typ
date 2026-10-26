#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 05",
  subtitle: "Invocazione Remota, HTTP, RPC, RMI e gRPC",
  accent-color: rgb("#1a9133")
)

= 1. Dal Calcolo Locale alla Programmazione Distribuita

Nel calcolo monolitico, l'invocazione di funzione trasferisce il controllo tramite stack locale e registri CPU in memoria condivisa con semantica all-or-nothing. Nei sistemi distribuiti, la composizione di nodi separati distrugge le assunzioni monolitiche:
- *Disgiunzione della memoria*: Niente puntatori condivisi.
- *Latenza e Asimmetria*: RTT di rete $10^4 - 10^6$ volte più lento dell'accesso RAM.
- *Eterogeneità*: Endianness, padding, tipi primitivi e OS differenti.
- *Guasti Parziali e Concorrenza Indipendente*: Il mancato arrivo di una risposta lascia il client nell'incertezza (richiesta persa, server crashato prima/durante/dopo l'esecuzione, risposta persa).


= 2. Protocolli Request-Reply e il Protocollo HTTP

== 2.1 Primitive del Modello Request-Reply
- `doOperation(RemoteRef s, int operationId, byte[] arguments)`: Invocata dal client (bloccante).
- `getRequest()`: Invocata dal server per estrarre la richiesta (bloccante).
- `sendReply(byte[] reply, InetAddress clientHost, int clientPort)`: Risposta inviata dal server.

Varianti: *R (Request)*, *RR (Request-Reply)*, *RRA (Request-Reply-Acknowledge Reply)*.

== 2.2 HTTP e Proprietà Formali RESTful
- *Safety (Sicurezza)*: L'operazione produce solo letture senza alterare lo stato del server (`GET`, `HEAD`, `OPTIONS`, `TRACE`).
- *Idempotence (Idempotenza)*: L'effetto di eseguire l'operazione $N$ volte coincide con l'effetto di eseguirla una sola volta ($f(f(x)) = f(x)$). Metodi idempotenti: `GET`, `HEAD`, `PUT`, `DELETE`, `OPTIONS`, `TRACE`. `POST` e `PATCH` non sono garantiti idempotenti.


= 3. RPC e RMI: Modello Stub-Skeleton

I framework RPC/RMI isolano il programmatore dalla rete tramite intermediari generati automaticamente:
- *Client Stub*: Esegue il marshalling dei parametri e invia la richiesta via rete.
- *Server Stub (Skeleton)*: Riceve i byte, esegue l'unmarshalling e invoca il metodo reale sull'istanza del server.

#callout(title: "Remote Object Reference (128 bit)", kind: "definition")[
Un riferimento a oggetto remoto garantisce l'unicità nello spazio e nel tempo:
- *IP Address & Port Number* (64 bit): Endpoint di rete dell'host server.
- *Creation Timestamp* (32 bit): Istante di avvio/creazione per evitare collisioni da riavvio.
- *Object Number* (32 bit): Contatore atomico locale al processo server.
- *Interface Specification*: Firma dei metodi invocabili sull'oggetto.
]


= 4. External Data Representation: CDR vs NDR

- *Canonical Format (CORBA CDR, XDR)*: I dati vengono tradotti dal mittente in un formato standard concordato a priori. In CORBA CDR, i tipi sono allineati a multipli della loro dimensione e *non vengono trasmessi metadati di tipo* (lo schema IDL è noto a priori a Stub e Skeleton).
- *Receiver-Makes-Right (NDR / DCE RPC)*: Il mittente invia i byte grezzi con un header che descrive l'hardware locale; il destinatario converte solo se la propria architettura differisce.


= 5. Semantiche di Chiamata e Tolleranza ai Guasti

#table(
  columns: (1.5fr, 1.5fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Semantica* ], [ *Garante / Meccanismo* ], [ *Comportamento in caso di Guasto* ],
  [ *Maybe* ], [ Nessun retry, nessun filtro. ], [ L'operazione è eseguita 0 o 1 volta. Nessun riscontro. ],
  [ *At-Least-Once* ], [ Retry automatico, nessun filtro duplicati. ], [ L'operazione è eseguita $>= 1$ volte. Sicura solo se idempotente. ],
  [ *At-Most-Once* ], [ Retry automatico + Filtro duplicati + Reply History. ], [ L'operazione è eseguita esattamente 1 volta se ha successo, o 0 in caso di errore. ]
)

#callout(title: "L'Impossibilità dell'Exactly-Once e Tecniche Moderne", kind: "warning")[
L'Exactly-Once trasparente è teoricamente irrealizzabile in presenza di crash arbitrari dei server (Spector, 1982). Nelle architetture moderne si adottano:
1. *Deadlines e Timeouts Propagati*: Limite temporale assoluto propagato lungo la catena di chiamata.
2. *Exponential Backoff con Full Jitter*: $T_"sleep" = text("random")(0, T_"base" times 2^text("attempt"))$ per prevenire thundering herd.
3. *Idempotency Keys (UUID)*: Chiavi univoche per deduping atomico nello storage distribuito.
]


= 6. IDL e Protocol Buffers

Gli *Interface Definition Languages (IDL)* specificano il contratto vincolante e neutrale tra client e server.
Google Protocol Buffers (Protobuf) usa schema binario con tag numerici (*Field Numbers*):
- I nomi dei campi non viaggiano sulla rete (risparmio 60-80% di payload rispetto a JSON).
- I campi rimossi si marcano con la parola chiave `reserved` per impedire il riutilizzo del tag.


= 7. gRPC e i 4 Pattern di Comunicazione

gRPC usa Protobuf come IDL e HTTP/2 per il multiplexing:
1. *Unary RPC*: Singola richiesta -> Singola risposta.
2. *Server Streaming RPC*: Singola richiesta -> Flusso (*stream*) di risposte.
3. *Client Streaming RPC*: Flusso (*stream*) di richieste -> Singola risposta.
4. *Bidirectional Streaming RPC*: Flusso di richieste <-> Flusso di risposte concorrente.

```protobuf
syntax = "proto3";

package greeter;

option go_package = "greeter/proto";

message GreetRequest {
    string name = 1;
}

message GreetReply {
    string greeting = 1;
}

service GreeterService {
    rpc Greet (GreetRequest) returns (GreetReply);
}
```
