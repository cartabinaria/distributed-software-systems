// dispensa.typ — Tema evoluto per dispense e appunti universitari

// --- MACRO CALLOUT SEMANTICI ---
#let callout(
  title: "",
  kind: "info", // "info", "warning", "success", "definition", "example"
  fill-color: none,
  stroke-color: none,
  title-color: none,
  body,
) = {
  let styles = (
    info: (fill: rgb("#eff6ff"), stroke: rgb("#93c5fd"), title: rgb("#1e40af")),
    warning: (fill: rgb("#fffbe2"), stroke: rgb("#fde047"), title: rgb("#854d0e")),
    success: (fill: rgb("#f0fdf4"), stroke: rgb("#86efac"), title: rgb("#166534")),
    definition: (fill: rgb("#f8fafc"), stroke: rgb("#cbd5e1"), title: rgb("#0f172a")),
    example: (fill: rgb("#fcf4ff"), stroke: rgb("#f0abfc"), title: rgb("#701a75")),
  )
  let current = styles.at(kind, default: styles.info)
  let f-color = if fill-color != none { fill-color } else { current.fill }
  let s-color = if stroke-color != none { stroke-color } else { current.stroke }
  let t-color = if title-color != none { title-color } else { current.title }

  v(0.4em)
  block(
    fill: f-color,
    stroke: 0.5pt + s-color,
    width: 100%,
    inset: 10pt,
    radius: 4pt,
    [
      #if title != "" [
        #text(weight: "bold", size: 0.95em, fill: t-color)[#title]
        #v(0.3em)
      ]
      #text(size: 0.9em, fill: rgb("#334155"))[#body]
    ],
  )
  v(0.4em)
}

// --- TEMPLATE PRINCIPALE ---
#let dispensa(
  title: "",
  subtitle: "",
  course: "Sistemi Software Distribuiti",
  academic-year: "A.A. 2026/2027",
  author: "",
  accent-color: rgb("#1a9133"),
  disclaimer: true,
  body,
) = {
  // Metadati PDF
  let full-title = if subtitle != "" { title + " - " + subtitle } else { title }
  set document(title: full-title, author: author)

  // Configurazione Pagina
  set page(
    paper: "a4",
    margin: (x: 2cm, y: 2.5cm),
    header: context {
      if here().page() > 1 {
        text(9pt, fill: luma(120), font: ("Alice", "Liberation Serif", "DejaVu Serif", "serif"))[
          _#course.split("—").at(0).trim()_ - #title
          #h(1fr)
          #academic-year
        ]
      }
    },
    footer: align(right)[ #text(size: 9pt, fill: rgb("#718096"))[#context counter(page).display()] ],
  )

  // Tipografia globale
  set heading(numbering: "1.1")
  set text(font: ("Inter", "Liberation Sans", "DejaVu Sans", "sans-serif"), size: 10pt, lang: "it")
  set par(justify: true, leading: 0.65em)

  // Titoli con accent-color dinamico
  show heading: set text(font: ("Alice", "Liberation Serif", "DejaVu Serif", "serif"), fill: accent-color)
  show heading.where(level: 1): it => [
    #v(0.6em)
    #it
    #v(0.2em)
  ]

  // Styling automatico per blocchi di codice
  show raw.where(block: true): it => [
    #v(0.3em)
    #block(
      fill: rgb("#f8fafc"),
      stroke: 0.5pt + rgb("#e2e8f0"),
      inset: 10pt,
      radius: 4pt,
      width: 100%,
      text(size: 8.5pt, font: ("Cascadia Code", "DejaVu Sans Mono", "monospace"), it),
    )
    #v(0.3em)
  ]

  // Intestazione Prima Pagina
  align(center)[
    #text(font: ("Alice", "Liberation Serif", "serif"), size: 18pt, weight: "bold", fill: rgb("#0f172a"))[#title]
    #v(1pt)
    #if subtitle != "" [
      #text(font: ("Alice", "Liberation Serif", "serif"), size: 13pt, style: "italic", fill: rgb("#475569"))[#subtitle]
      #v(0.01em)
    ]
    #text(size: 8pt, fill: rgb("#475569"))[#course]
    #if author != "" [
      #h(1fr)
      #text(size: 8pt, fill: rgb("#64748b"))[A cura di: #author]
    ]
    #v(0.1em)
    #line(length: 100%, stroke: 1.5pt + accent-color)
  ]

  v(1em)

  // Nota / Disclaimer
  if disclaimer [
    #block(
      fill: rgb("#f4f6f8"),
      stroke: 0.5pt + rgb("#cbd5e1"),
      width: 100%,
      inset: 12pt,
      radius: 4pt,
    )[
      #text(weight: "bold", size: 0.95em, fill: rgb("#1e293b"))[Nota sulla redazione del materiale]
      #v(0.3em)
      #set text(size: 0.85em, fill: rgb("#334155"))
      Queste dispense sono state rielaborate con il supporto di *NotebookLM*, utilizzando esclusivamente come fonti il materiale didattico fornito dal docente (slide, trascrizioni e dispense ufficiali).

      *Disclaimer:* Il presente documento ha uno scopo puramente didattico e di supporto allo studio individuale. Non sostituisce i testi consigliati o i materiali ufficiali del corso. Sebbene sia stato svolto un lavoro di revisione, potrebbero rimanere sviste o inesattezze dovute alla sintesi automatica: si invita pertanto a fare sempre riferimento alle fonti ufficiali.
    ]
    #v(0.8em)
  ]

  // Indice
  outline(
    title: [Indice della Lezione],
    depth: 2,
    indent: 1.2em,
  )

  v(1.5em)

  body
}
