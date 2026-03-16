# RAG Notebook Template Structure

This document describes the standard structure for RAG implementation notebooks in the MCP orchestration system.

## Overview

Each RAG notebook should follow a consistent structure that enables:

- **Parameter injection** via Papermill for dynamic execution
- **Standardized output** via Scrapbook for result collection
- **Clear separation** of concerns (indexing, retrieval, generation)
- **Flexible return options** using boolean parameters
- **Cross-platform compatibility** with proper path handling
- **Error handling** with standardized error response format

**UPDATE (2025-08-13)**: Added standardized error handling pattern and improved path resolution.

## Path Handling for Different Environments

The notebooks are designed to work in various environments:
- **Local Jupyter** - Standard notebook execution
- **VS Code** - Both local and web versions  
- **Azure ML** - Cloud notebook environments
- **Papermill** - Automated execution from different working directories

The template includes robust path resolution using `Path(__file__).parent` that works regardless of the current working directory.

## Required Cell Structure

### 1. Parameters Cell (REQUIRED)

The first code cell must be tagged with `"parameters"` for Papermill injection:

```python
# === PARAMETERS CELL (tagged "parameters") ===
query = "What is machine learning?"
return_chunks = True   # Return relevant text chunks
return_answer = True   # Return generated answer  
reindex = False        # True to rebuild index
```

**Parameter Guidelines:**

- `query`: The search/question string (REQUIRED for all RAG tools)
- `return_chunks`: Boolean flag to return retrieved text chunks
- `return_answer`: Boolean flag to return generated answer
- `reindex`: Boolean flag to rebuild the vector index
- Add method-specific parameters as needed (similarity_threshold, max_results, etc.)

### 2. Imports and Setup Cell

Import only the essential libraries for MCP integration:

```python
# === IMPORTS AND SETUP ===
import time
import scrapbook as sb
from pathlib import Path

# Get the directory containing this notebook for relative paths
NOTEBOOK_DIR = Path.cwd()  # For regular Jupyter
# Alternative for VS Code/Azure ML environments:
# NOTEBOOK_DIR = Path(__file__).parent if '__file__' in globals() else Path.cwd()

# Add implementation-specific imports as needed:
# from sentence_transformers import SentenceTransformer
# import faiss, chromadb, pinecone, etc.
# import openai, anthropic, etc.
```

### 3. Indexing Logic Cell

Handle index creation/loading based on `reindex` parameter:

```python
# === INDEXING LOGIC ===
if reindex:
    print("🔄 Re-indexing corpus...")
    # Build new vector index using your chosen method
    # Use NOTEBOOK_DIR for relative paths:
    # corpus_path = NOTEBOOK_DIR / "data" / "corpus.jsonl"
    # index_path = NOTEBOOK_DIR / "data" / "vector_index"
    # Save to index_path
    print("✅ Index rebuilt")
else:
    print("📂 Loading existing index...")
    # Load from index_path using NOTEBOOK_DIR
    # index_path = NOTEBOOK_DIR / "data" / "vector_index"
```

### 4. Retrieval Logic Cell

Retrieve relevant chunks when needed:

```python
# === RETRIEVAL LOGIC ===
if return_chunks or return_answer:
    print(f"🔍 Retrieving relevant chunks for: '{query}'")
    start_time = time.time()
  
    # Your retrieval implementation here
    relevant_chunks = retrieve_chunks(query, top_k=5)
  
    retrieval_time = time.time() - start_time
    print(f"📋 Found {len(relevant_chunks)} relevant chunks in {retrieval_time:.3f}s")
```

### 5. Generation Logic Cell

Generate answers when requested:

```python
# === GENERATION LOGIC ===
if return_answer:
    print("🤖 Generating answer...")
    start_time = time.time()
    
    # Use the chunks we already retrieved
    answer = generate_answer(query, relevant_chunks)
    
    generation_time = time.time() - start_time
    print(f"💡 Generated answer: {answer[:100]}...")
```

### 6. Metrics Collection Cell

Collect performance and quality metrics:

```python
# === METRICS COLLECTION ===
metrics = {
    "query_length": len(query),
    "retrieval_time": retrieval_time if (return_chunks or return_answer) else 0,
    "generation_time": generation_time if return_answer else 0,
    "chunks_retrieved": len(relevant_chunks) if (return_chunks or return_answer) else 0,
    "confidence": calculate_confidence() if return_answer else None,
    "method": "your_method_name",  # e.g., "semantic_search", "hybrid_rag"
    "timestamp": time.time()
}
```

### 7. Output Cell (REQUIRED)

Use Scrapbook to output results for MCP collection:

```python
# === OUTPUT VIA SCRAPBOOK ===
import scrapbook as sb

# Build complete data object
data = {
    "version": "your_method@v1.0",
    "metrics": metrics
}

# Add requested outputs
if return_answer:
    data["answer"] = answer
if return_chunks:
    data["chunks"] = relevant_chunks

# Output single data field with everything
sb.glue("data", data)

print(f"✅ Processing complete! Returned: {'chunks' if return_chunks else ''}{',' if return_chunks and return_answer else ''}{'answer' if return_answer else ''}")
```

## Implementation Guidelines

### MCP Output Format (Required)

The notebook outputs a single standardized field:

- `data`: JSON object containing all results including version, metrics, and any other data

**Note**: The `data` field contains the complete response structure. LLMs will inspect and work with whatever JSON structure is returned.

### Error Handling (UPDATED 2025-08-13)

**Standardized Error Response Pattern:**

All notebooks should use this error handling pattern for consistency with the MCP server:

```python
try:
    # Your RAG implementation here
    # ... retrieval logic ...
    # ... generation logic ...
    
    # Success case
    data = {
        "status": "success",
        "version": "your_method@v1.0",
        "answer": answer if return_answer else None,
        "chunks": relevant_chunks if return_chunks else None,
        "metrics": metrics
    }
    
except Exception as e:
    print(f"❌ Error in RAG implementation: {e}")
    import traceback
    traceback.print_exc()
    
    # Standardized error response
    data = {
        "status": "error",
        "error": str(e),
        "error_type": type(e).__name__,
        "version": "your_method@v1.0",
        "metrics": {"status": "error"}
    }

# Always output the data object
sb.glue("data", data)
```

**Error Response Benefits:**
- Consistent error format across all RAG implementations
- Proper error propagation to MCP clients
- Debugging information included
- Graceful failure handling

### Enhanced Error Categories

```python
# Network/API errors
except requests.RequestException as e:
    error_type = "network_error"
    
# File/path errors  
except (FileNotFoundError, IOError) as e:
    error_type = "file_error"
    
# Model/embedding errors
except (ImportError, RuntimeError) as e:
    error_type = "model_error"
    
# Parameter validation errors
except ValueError as e:
    error_type = "parameter_error"
    
# Generic fallback
except Exception as e:
    error_type = "unknown_error"
```

### Performance Optimization

- Cache loaded models and indices
- Use batch processing for multiple queries
- Monitor memory usage for large corpora
- Include timing information in metrics

## Example Methods to Implement

1. **Semantic Search**: Vector similarity using embeddings
2. **Keyword Search**: BM25 or TF-IDF based retrieval
3. **Hybrid RAG**: Combination of semantic + keyword
4. **Multi-hop RAG**: Iterative retrieval and reasoning
5. **Reranking RAG**: Initial retrieval + learned reranking

## Integration with MCP Server

Each notebook becomes a tool in the MCP server with:

- Method name as tool name (e.g., `rag_semantic_search`)
- Parameters mapped to notebook parameters
- Results extracted via Scrapbook glue values
- Metrics used for performance comparison

This standardized structure enables easy comparison between different RAG approaches and seamless integration with the MCP orchestration system.
