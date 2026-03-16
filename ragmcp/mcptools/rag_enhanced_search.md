---
name: rag_enhanced_search
version: "2.0"
notebook: workers/rag_hello_two_mcp.ipynb
category: advanced
tags: [enhanced, analytics, reranking, complex]
parameters:
  query:
    type: str
    required: true
    description: "Complex multi-part questions"
    examples: ["Compare supervised vs unsupervised learning", "Explain the relationship between AI, ML, and deep learning", "What are the pros and cons of different optimization algorithms?"]
  return_chunks:
    type: bool
    default: false
    description: "Return chunks with enhanced metadata"
  return_answer:
    type: bool
    default: true
    description: "Return comprehensive generated answer"
  reindex:
    type: bool
    default: false
    description: "Rebuild enhanced search index"
---

# RAG Enhanced Search

Advanced search with enhanced processing and detailed analytics.

## Description

This tool provides more sophisticated retrieval-augmented generation
with enhanced processing capabilities, chunk analysis, and detailed
performance metrics. Suitable for complex queries requiring deeper analysis.

## Advanced Features

- Enhanced confidence scoring
- Chunk analysis and reporting
- Advanced processing methods
- Extended capability reporting
- Multi-hop reasoning

## Returns

The data object from the notebook containing:
- **version**: Tool version identifier
- **metrics**: Extended performance metrics (always included)
- **chunks**: Enhanced chunks with metadata (if return_chunks=True)
- **answer**: Generated response (if return_answer=True)
- **capabilities**: Tool capabilities for introspection

## Best For

- **Complex queries**: Multi-part questions requiring deep analysis
- **Research tasks**: Comprehensive information gathering
- **Analytical workflows**: When you need detailed metrics

## Example Usage

### Get enhanced answer
```python
result = rag_enhanced_search("How do transformers work in NLP?")
print(result["answer"])  # Direct access
```

### Get enhanced chunks for reranking
```python
result = rag_enhanced_search("AI concepts", return_chunks=True, return_answer=False)
chunks = result["chunks"]  # Enhanced chunks with metadata
```

### Get full analysis
```python
result = rag_enhanced_search("ML overview", return_chunks=True, return_answer=True)
print(result["capabilities"])  # Tool capabilities
```
