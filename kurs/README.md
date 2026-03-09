# 🏫 PIRAGE RAG Trainingskurs

> **Retrieval-Augmented Generation von Grund auf** — auf Deutsch, mit echten Code-Übungen in Google Colab.

---

## Was ist PIRAGE?

**PIRAGE** ist das Framework für diesen Kurs — ein Akronym das den gesamten RAG-Lebenszyklus beschreibt:

| Buchstabe | Phase | Beschreibung |
|-----------|-------|-------------|
| **P** | **Parse** | Dokumente einlesen, Text extrahieren, aufbereiten |
| **I** | **Index** | Embeddings erstellen, Vektorindex aufbauen |
| **R** | **Retrieval** | Relevante Chunks zu einer Anfrage finden |
| **AG** | **Augmented Generation** | Kontext + LLM → präzise Antwort |
| **E** | **Evaluation** | Pipeline messen, Fehler debuggen, optimieren |

---

## Kursstruktur (3 Tage / 12 Sessions)

### Tag 1 — Grundlagen & erste Schritte

| Session | Titel | Notebook | Colab |
|---------|-------|----------|-------|
| 1 | Grundlagen von RAG | [01_grundlagen_rag.ipynb](session_01_grundlagen/01_grundlagen_rag.ipynb) | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/kurs/session_01_grundlagen/01_grundlagen_rag.ipynb) |
| 2–3 | Naive RAG — Einrichtung & Chunking | [02_naive_rag.ipynb](session_02_naive_rag/02_naive_rag.ipynb) | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/kurs/session_02_naive_rag/02_naive_rag.ipynb) |
| 4 | Hybrid RAG — BM25 + FAISS | _(coming soon)_ | — |

### Tag 2 — Verbesserung & Kontextverständnis

| Session | Titel | Notebook | Colab |
|---------|-------|----------|-------|
| 5 | Query Expansion & Neural Reranking | _(coming soon)_ | — |
| 6 | Graph-basiertes Retrieval | _(coming soon)_ | — |
| 7 | Kontextbewusstes Retrieval (Chat-History) | _(coming soon)_ | — |
| 8 | Performance-Optimierung | _(coming soon)_ | — |

### Tag 3 — Fortgeschrittene Techniken & Agentic RAG

| Session | Titel | Notebook | Colab |
|---------|-------|----------|-------|
| 9 | Erweiterte hybride Retrieval-Strategien | _(coming soon)_ | — |
| 10 | Multi-Step Retrieval & Agentic Approaches | _(coming soon)_ | — |
| 11 | Benchmarking & Fehleranalyse | _(coming soon)_ | — |
| 12 | Abschluss & nächste Schritte | _(coming soon)_ | — |

---

## 🛠️ Technologie

Alle Notebooks laufen **kostenlos in Google Colab** — kein lokales Setup, keine API-Keys erforderlich.

- **Embeddings**: `sentence-transformers` (all-MiniLM-L6-v2, ~80MB, läuft auf Colab Free Tier)
- **Vektorsearch**: FAISS (Facebook AI Similarity Search)
- **LLM-optional**: Notebooks zeigen das Retrieval vollständig; für die Generierung sind kostenlose Alternativen angegeben

---

## 🎯 Zielgruppe

- Entwickler & Ingenieure, die mit KI-Retrieval-Systemen arbeiten
- Data Scientists, die Such- & Retrieval-Pipelines verstehen möchten
- KI-Enthusiasten, die praktische RAG-Anwendungen erkunden möchten

---

*Kurs basiert auf dem LearnRAG-Material. 🦃 Maintained by [Crunch](https://github.com/Copilotclaw/trainingdemo)*
