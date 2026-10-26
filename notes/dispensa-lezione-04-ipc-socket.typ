#import "dispensa-theme.typ": dispensa, callout

#show: dispensa.with(
  title: "Lezione 04",
  subtitle: "Interprocess Communication (IPC), Socket e Serializzazione",
  accent-color: rgb("#1a9133")
)

= 1. Primitive e Modelli di IPC

L'Interprocess Communication (IPC) definisce i meccanismi con cui processi distinti scambiano dati e coordinano l'esecuzione.

== 1.1 IPC Locale vs IPC Distribuita
- *IPC Locale (stessa macchina)*: Può essere realizzata sia tramite memoria condivisa (*Shared Memory*, estremamente veloce) sia tramite passaggio di messaggi gestito dal kernel locale (pipes, message queues, Unix domain sockets).
- *IPC Distribuita (macchine diverse)*: Si basa esclusivamente sul passaggio di messaggi attraverso la rete mediante canali di comunicazione denominati *Sockets*.


= 2. Sockets e Indirizzamento di Rete

Un *Socket* costituisce l'astrazione di un endpoint di comunicazione bidirezionale fornito dal sistema operativo.

#callout(title: "Indirizzamento del Socket Endpoint", kind: "definition")[
Un socket endpoint univoco nell'intera rete è identificato dalla coppia:
$$ text("Endpoint Socket") = text("Indirizzo IP") + text("Numero di Porta TCP/UDP") $$
Le porte da 0 a 1023 sono riservate ai servizi di sistema (*Well-Known Ports*, es. HTTP 80, HTTPS 443), mentre le porte da 1024 a 65535 sono utilizzabili per applicazioni utente o assegnate dinamicamente (*Ephemeral Ports*).
]


= 3. Ciclo di Vita delle Socket TCP (Client-Server)

L'interazione tra un server ed un client TCP segue una sequenza precisa di chiamate di sistema (API Socket):

#table(
  columns: (1fr, 2fr, 2fr),
  fill: (x, y) => if y == 0 { rgb("#f8fafc") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Fase* ], [ *Lato Server* ], [ *Lato Client* ],
  [ *1. Inizializzazione* ], [ `socket()` -> Crea l'endpoint di rete. ], [ `socket()` -> Crea l'endpoint locale. ],
  [ *2. Binding & Ascolto* ], [ `bind()` -> Associa IP e Porta. \ `listen()` -> Mette il socket in ascolto passivo. ], [ N/A (Porta assegnata dinamicamente). ],
  [ *3. Connessione* ], [ `accept()` -> Bloccante. Attende richieste di connessione client. ], [ `connect()` -> Avvia il 3-Way Handshake TCP verso il server. ],
  [ *4. Sessione Dati* ], [ `read()` / `write()` o `recv()` / `send()` sul socket dedicato restituito da `accept()`. ], [ `write()` / `read()` o `send()` / `recv()` sul socket connesso. ],
  [ *5. Chiusura* ], [ `close()` -> Rilascia il socket e chiude il canale. ], [ `close()` -> Rilascia il socket. ]
)


= 4. Serializzazione e Marshalling dei Dati

Quando due processi su macchine eterogenee scambiano strutture dati o oggetti, devono convertire la rappresentazione interna di memoria in un flusso portabile di byte.

== 4.1 Distinzione Formale
- *Serialization (Serializzazione)*: Processo di conversione di una struttura dati o grafo di oggetti in una sequenza unidimensionale di byte trasmissibile via rete o salvabile su disco.
- *Deserialization*: Operazione inversa di ricostruzione dello stato originale in memoria.
- *Marshalling*: Operazione di livello superiore (tipica di RPC/RMI) che, oltre a serializzare i dati, raccoglie e confeziona metadati di contesto (ID del metodo remoto, identificatore di interfaccia, token di sicurezza).
- *Unmarshalling*: Operazione inversa del marshalling lato ricevente, propedeutica al dispatching della chiamata.

== 4.2 Formati di Rappresentazione Esterna

#table(
  columns: (1.2fr, 1.2fr, 1.8fr, 1.8fr),
  fill: (x, y) => if y == 0 { rgb("#eff6ff") } else { none },
  stroke: 0.5pt + rgb("#cbd5e1"),
  [ *Formato* ], [ *Tipo* ], [ *Vantaggi* ], [ *Svantaggi / Note* ],
  [ *XML* ], [ Textual / Markup ], [ Supporta validazione rigorosa via XML Schema (XSD) e Namespaces. ], [ Molto verboso, consumo elevato di banda e parsing lento. ],
  [ *JSON* ], [ Textual / Key-Value ], [ Leggero, compatibile con tutti i linguaggi, leggibile da umani. ], [ Manca di uno schema rigoroso nativo. ],
  [ *YAML* ], [ Textual / Indented ], [ Estremamente leggibile, supporta commenti e strutture nidificate. ], [ Sensibile all'indentazione (stile Python). ]
)


= 5. Laboratorio Pratico: Produttore-Consumatore Concorrente Cifrato

Di seguito è riportata l'implementazione completa in Python del sistema Produttore-Consumatore basato su `threading`, `queue.Queue`, serializzazione JSON e cifratura simmetrica `Fernet`:

```python
import json
import time
import random
import threading
from queue import Queue
from cryptography.fernet import Fernet

# Generazione della chiave simmetrica condivisa
KEY = Fernet.generate_key()
cipher = Fernet(KEY)

# Coda condivisa sincronizzata a dimensione limitata
shared_queue = Queue(maxsize=5)

def producer(producer_id):
    while True:
        # 1. Generazione dati di dominio
        data = {
            "producer_id": producer_id,
            "valore": random.randint(1, 100),
            "timestamp": time.time()
        }
        
        # 2. Serializzazione JSON e codifica in byte
        json_bytes = json.dumps(data).encode('utf-8')
        
        # 3. Cifratura simmetrica del payload
        encrypted_data = cipher.encrypt(json_bytes)
        
        # 4. Inserimento in coda sincronizzata
        shared_queue.put(encrypted_data)
        print(f"[Producer {producer_id}] Inserito dato cifrato in coda.")
        
        time.sleep(random.uniform(0.5, 1.5))

def consumer(consumer_id):
    while True:
        # 1. Estrazione bloccante dalla coda
        encrypted_data = shared_queue.get()
        
        # 2. Decifratura
        decrypted_bytes = cipher.decrypt(encrypted_data)
        
        # 3. Deserializzazione JSON
        data = json.loads(decrypted_bytes.decode('utf-8'))
        
        print(f"  --> [Consumer {consumer_id}] Elaborato correttamente: {data}")
        shared_queue.task_done()
        
        time.sleep(random.uniform(0.8, 1.8))

if __name__ == "__main__":
    # Avvio di 2 Thread Produttori e 1 Thread Consumatore
    for p_id in range(1, 3):
        threading.Thread(target=producer, args=(p_id,), daemon=True).start()
        
    threading.Thread(target=consumer, args=(1,), daemon=True).start()
    
    # Mantiene il main thread in esecuzione per 10 secondi
    time.sleep(10)
```

#callout(title: "Considerazioni di Sicurezza e Concorrenza", kind: "success")[
- *Riservatezza (Confidentiality)*: La cifratura Fernet impedisce la lettura del payload JSON da parte di eventuali processi ostili in ascolto sul canale o sulla coda.
- *Thread Safety*: La struttura `queue.Queue` gestisce internamente la sincronizzazione con lock e variabili di condizione, prevenendo race conditions tra thread produttori e consumatori.
]
