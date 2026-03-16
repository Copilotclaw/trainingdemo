# 🦃 Training Demos — Copilotclaw

A public repo of AI/ML training notebooks managed by **Crunch** (Copilotclaw's AI agent).

> Notebooks are designed to run in **Google Colab with one click** — no local install required.  
> 🦙 Ollama variants run **fully offline** on your own machine.

---

## 📚 Notebooks

| Notebook | Topic | Open | Explainer |
|----------|-------|------|-----------|
| [human-rag-exercise.ipynb](human-rag-exercise.ipynb) | **Human RAG** — understand retrieval by doing it on paper first | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/human-rag-exercise.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | *(start here!)* |
| [simple-rag-demo.ipynb](simple-rag-demo.ipynb) | RAG with FAISS + SentenceTransformers | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/simple-rag-demo.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | <a href="https://htmlpreview.github.io/?https://github.com/Copilotclaw/trainingdemo/blob/main/explainer.html" target="_blank"><img src="https://img.shields.io/badge/📖_Explainer-View-7c3aed?style=flat-square&logo=html5&logoColor=white" alt="View Explainer"/></a> |
| [simple-rag-demo-ollama.ipynb](simple-rag-demo-ollama.ipynb) | 🦙 **Local RAG with Ollama** — same pipeline but with real LLM generation, fully offline | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/simple-rag-demo-ollama.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | *requires Ollama* |
| [qwen35-tiny-rag-demo.ipynb](qwen35-tiny-rag-demo.ipynb) | 👁️ **Qwen 3.5 Tiny + Vision RAG** — 0.8B–9B models with native image understanding, fully offline or via DashScope API | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/qwen35-tiny-rag-demo.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | *Ollama or ALIKEY* |
| [simple-rag-demo-java.ipynb](simple-rag-demo-java.ipynb) | ☕ **RAG in Java** — same pipeline in pure Java with TF-IDF (no Python libs, runs in Colab via `javac`/`java`) | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/simple-rag-demo-java.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | *(compare with Python!)* |
| [ragmcp-start.ipynb](ragmcp-start.ipynb) | 🚀 **RAG MCP Starter** — clone the full `ragmcp` repo and explore all its notebooks from Colab | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/ragmcp-start.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | *(start here for ragmcp!)* |
| [rag-techniques-ollama.ipynb](rag-techniques-ollama.ipynb) | 🔬 **Advanced RAG Techniques** — HyDE, MultiQuery, Step-Back, Re-Ranking, BM25, Dense Embedding with Ollama | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/rag-techniques-ollama.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> | <a href="https://htmlpreview.github.io/?https://github.com/Copilotclaw/trainingdemo/blob/main/rag-techniques-explainer.html" target="_blank"><img src="https://img.shields.io/badge/📖_Explainer-View-7c3aed?style=flat-square&logo=html5&logoColor=white" alt="View Explainer"/></a> |

---

## 🔍 What's in the RAG notebook?

The `simple-rag-demo.ipynb` notebook walks through the full RAG pipeline:

1. **Build a knowledge base** — a small set of documents about RAG, FAISS, and local LLMs
2. **Embed documents** using `sentence-transformers` (all-MiniLM-L6-v2, ~80MB, runs in Colab free tier)
3. **Index with FAISS** — efficient vector similarity search by Meta
4. **Query the index** — retrieve top-k most relevant documents for any question
5. **Build a prompt** — see how retrieved context becomes an LLM input
6. **Exercises** — extend it yourself

No API keys. No cloud credits. Runs fully in Colab.

---

## 🚀 Quick Start

**Colab (recommended):** Click the badge above → runs in your browser in ~60 seconds.

**Local:**
```bash
git clone https://github.com/Copilotclaw/trainingdemo
cd trainingdemo
pip install sentence-transformers faiss-cpu jupyter
jupyter notebook simple-rag-demo.ipynb
```

---

## 🏫 PIRAGE RAG Trainingskurs (Deutsch)

Ein vollständiger 3-Tage RAG-Kurs auf Deutsch — basierend auf dem LearnRAG-Material.
Kein API-Key, kein lokales Setup — läuft in **Google Colab**.

> **PIRAGE**: Parse → Index → Retrieval → Augmented Generation → Evaluation

| Session | Titel | Notebook | Colab |
|---------|-------|----------|-------|
| 1 | Grundlagen von RAG + PIRAGE-Framework | [01_grundlagen_rag.ipynb](kurs/session_01_grundlagen/01_grundlagen_rag.ipynb) | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/kurs/session_01_grundlagen/01_grundlagen_rag.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> |
| 2+3 | Naive RAG — Einrichtung & Chunking | [02_naive_rag.ipynb](kurs/session_02_naive_rag/02_naive_rag.ipynb) | <a href="https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/kurs/session_02_naive_rag/02_naive_rag.ipynb" target="_blank"><img src="https://colab.research.google.com/assets/colab-badge.svg" alt="Open In Colab"/></a> |
| 4–12 | Hybrid RAG, GraphRAG, Agentic RAG… | *(coming soon)* | — |

→ [Vollständige Kursübersicht](kurs/README.md)

---

## 🛠️ Generating Explainers

Each notebook has an auto-generated HTML explainer. To regenerate or add one for a new notebook:

```bash
# Install the one dependency
pip install openai

# Generate (requires ALIKEY or AZURE_API_KEY env var)
python scripts/generate_explainer.py my-notebook.ipynb

# Test without an LLM key
python scripts/generate_explainer.py my-notebook.ipynb --no-llm

# Custom output path
python scripts/generate_explainer.py my-notebook.ipynb --output my-notebook-explainer.html
```

The script calls [Ali qwen3-coder-plus](https://dashscope.aliyuncs.com) (or Azure as fallback) to write the explainer content, then renders it as a polished HTML page with hero, steps, key concepts, and a CTA.

> **Auto-generation**: add `.github/workflows/generate-explainers.yml` (file is ready in the repo root — needs a user with `workflows` permission to commit it) to auto-regenerate on every notebook push.

---

## 🦃 About

This repo is managed by [Crunch](https://github.com/Copilotclaw/copilotclaw) — an AI agent running on GitHub Actions. Notebooks are generated and committed autonomously based on training needs.

*More notebooks coming as training topics expand.*
