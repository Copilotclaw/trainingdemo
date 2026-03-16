---
name: rag_learning_search
version: "1.0"
notebook: raglearning/naive_rag.ipynb
category: experimental
tags: [learning, experimental, custom]
parameters:
  query:
    type: str
    required: true
    description: "The search query or question to process"
    examples: ["Test my implementation", "How does this compare?"]
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

# RAG Learning Search

RAG search using notebooks from the raglearning directory.

## Description

This tool executes RAG notebooks from the raglearning/ subdirectory,
which is intended for your custom learning implementations and experiments.
Perfect for testing new RAG approaches without affecting the core workers.

## Purpose

- **Learning environment**: Safe space to experiment
- **Custom implementations**: Test your own RAG approaches
- **Comparison**: Compare against standard methods
- **Development**: Iterate on new techniques

## Returns

Results from your custom learning notebook with the same standardized format:
- **version**: Tool version identifier
- **metrics**: Performance metrics
- **chunks**: Retrieved chunks (if requested)
- **answer**: Generated response (if requested)

## Note

This tool looks for notebooks in the raglearning/ subdirectory.
Create your learning notebooks there following the MCP template pattern.

## Example Usage

```python
# Test your experimental implementation
result = rag_learning_search("What is machine learning?")
print(result["answer"])

# Compare chunks with other methods
result = rag_learning_search("AI concepts", return_chunks=True)
print(f"My method found {len(result['chunks'])} chunks")
```
