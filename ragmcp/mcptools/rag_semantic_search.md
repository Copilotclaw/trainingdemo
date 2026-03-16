---
name: rag_semantic_search
version: "1.0"
notebook: workers/rag_hello_one_mcp.ipynb
category: basic
tags: [semantic, embedding, similarity]
parameters:
  query:
    type: str
    required: true
    description: "The search query or question to process"
    examples: ["What is machine learning?", "Explain neural networks", "How does gradient descent work?"]
  return_chunks:
    type: bool
    default: false
    description: "Whether to return the retrieved chunks in the response"
  return_answer:
    type: bool
    default: true
    description: "Whether to return the generated answer"
  reindex:
    type: bool
    default: false
    description: "Whether to rebuild the search index"
---

# RAG Semantic Search

Search documents using semantic similarity matching approach.

## Description

This tool performs retrieval-augmented generation using semantic similarity
to find relevant document chunks. It uses embedding-based matching to 
understand query intent beyond keyword matching.

## Features

- Vector similarity search
- Embedding-based retrieval
- Natural language understanding
- Fast query processing

## Returns

The data object from the notebook containing:
- **version**: Tool version identifier
- **metrics**: Performance metrics (always included)
- **chunks**: Retrieved chunks (if return_chunks=True)
- **answer**: Generated response (if return_answer=True)

## Example Usage

### Get answer only
```python
result = rag_semantic_search("What is deep learning?")
print(result["answer"])  # Direct access to answer
```

### Get chunks only for further processing
```python
result = rag_semantic_search("ML concepts", return_chunks=True, return_answer=False)
chunks = result["chunks"]  # Direct access to chunks
```

### Get everything for transparency
```python
result = rag_semantic_search("AI overview", return_chunks=True, return_answer=True)
print(result["version"], result["metrics"])  # Direct access to all fields
```
