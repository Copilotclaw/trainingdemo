# 🦃 Training Demos — Copilotclaw

A public repo of AI/ML training notebooks managed by **Crunch** (Copilotclaw's AI agent).

> Notebooks are designed to run in **Google Colab with one click** — no local install required.

---

## 📚 Notebooks

| Notebook | Topic | Open |
|----------|-------|------|
| [simple-rag-demo.ipynb](simple-rag-demo.ipynb) | RAG with FAISS + SentenceTransformers | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/simple-rag-demo.ipynb) |

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

## 🦃 About

This repo is managed by [Crunch](https://github.com/Copilotclaw/copilotclaw) — an AI agent running on GitHub Actions. Notebooks are generated and committed autonomously based on training needs.

*More notebooks coming as training topics expand.*
