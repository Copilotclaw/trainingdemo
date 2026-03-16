# RAG Orchestration Guide

This document describes how to combine multiple RAG tools to create sophisticated, composable AI workflows using the MCP orchestration system.

## Core Concept: Composable RAG

Instead of monolithic "do everything" RAG tools, this system provides focused building blocks that can be intelligently combined:

- **Simple Tools**: Each tool does one thing well (semantic search, keyword search, reranking, generation)
- **Flexible Output**: Tools return data in whatever format makes sense for their method
- **Intelligent Orchestration**: Developers or LLM agents combine tools creatively
- **Maximum Flexibility**: Boolean parameters (`return_chunks`, `return_answer`) enable precise control

## Tool Usage Patterns

### Basic Usage

```python
# Get chunks only for further processing
result = rag_semantic_search(
    query="What is machine learning?",
    return_chunks=True,
    return_answer=False
)
chunks = result["data"]["chunks"]

# Get answer only for end users
result = rag_semantic_search(
    query="What is machine learning?", 
    return_chunks=False,
    return_answer=True
)
answer = result["data"]["answer"]

# Get everything for transparency
result = rag_semantic_search(
    query="What is machine learning?",
    return_chunks=True, 
    return_answer=True
)
chunks = result["data"]["chunks"]
answer = result["data"]["answer"]
```

### Advanced Orchestration Patterns

#### 1. Multi-Method Fusion
Combine different retrieval approaches for better coverage:

```python
# Step 1: Get chunks from multiple methods
semantic_result = rag_semantic_search(query, return_chunks=True, return_answer=False)
keyword_result = rag_keyword_search(query, return_chunks=True, return_answer=False)

# Step 2: Combine and deduplicate chunks
all_chunks = semantic_result["data"]["chunks"] + keyword_result["data"]["chunks"]
unique_chunks = deduplicate_chunks(all_chunks)

# Step 3: Rerank combined results
rerank_result = rag_reranker(
    query=query,
    chunks=unique_chunks,
    return_chunks=True,
    return_answer=False
)

# Step 4: Generate final answer
final_result = rag_generator(
    query=query,
    chunks=rerank_result["data"]["chunks"][:5],
    return_chunks=False,
    return_answer=True
)
```

#### 2. Sub-Query Decomposition
Break complex queries into simpler parts:

```python
# Step 1: Decompose complex query
complex_query = "Compare machine learning and deep learning approaches for image recognition"
sub_queries = [
    "What is machine learning for image recognition?",
    "What is deep learning for image recognition?", 
    "How do ML and DL compare for images?"
]

# Step 2: Retrieve chunks for each sub-query
all_chunks = []
for sub_query in sub_queries:
    result = rag_semantic_search(sub_query, return_chunks=True, return_answer=False)
    all_chunks.extend(result["data"]["chunks"])

# Step 3: Generate comprehensive answer
final_result = rag_generator(
    query=complex_query,
    chunks=all_chunks,
    return_chunks=False,
    return_answer=True
)
```

#### 3. Iterative Refinement
Refine search based on initial results:

```python
# Step 1: Initial broad search
initial_result = rag_semantic_search(
    query="neural networks",
    return_chunks=True,
    return_answer=False
)

# Step 2: Analyze gaps in initial chunks
gaps = analyze_coverage(initial_result["data"]["chunks"])

# Step 3: Targeted follow-up searches
refined_chunks = []
for gap in gaps:
    refined_query = f"neural networks {gap}"
    result = rag_semantic_search(refined_query, return_chunks=True, return_answer=False)
    refined_chunks.extend(result["data"]["chunks"])

# Step 4: Combine and generate final answer
all_chunks = initial_result["data"]["chunks"] + refined_chunks
final_result = rag_generator(
    query="comprehensive overview of neural networks",
    chunks=all_chunks,
    return_chunks=True,
    return_answer=True
)
```

## Developer Implementation

### Handling Flexible Data Formats

Since each tool can return chunks in different formats, implement adaptive handling:

```python
def extract_text_from_chunks(chunks):
    """Extract text from chunks regardless of format."""
    texts = []
    for chunk in chunks:
        if isinstance(chunk, str):
            # Simple string format
            texts.append(chunk)
        elif isinstance(chunk, dict):
            # Object format - try common field names
            text = chunk.get("text") or chunk.get("content") or chunk.get("passage")
            if text:
                texts.append(text)
        else:
            # Convert to string as fallback
            texts.append(str(chunk))
    return texts

def get_chunk_scores(chunks):
    """Extract scores if available."""
    scores = []
    for chunk in chunks:
        if isinstance(chunk, dict) and "score" in chunk:
            scores.append(chunk["score"])
        else:
            scores.append(1.0)  # Default score
    return scores
```

### Performance Optimization

```python
def parallel_retrieval(query, methods):
    """Run multiple retrieval methods in parallel."""
    import concurrent.futures
    
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = {
            executor.submit(method, query, return_chunks=True, return_answer=False): method_name
            for method_name, method in methods.items()
        }
        
        results = {}
        for future in concurrent.futures.as_completed(futures):
            method_name = futures[future]
            results[method_name] = future.result()
    
    return results
```

## Agentic Implementation

### LLM Agent Workflow

```python
class RAGOrchestrator:
    def __init__(self, mcp_client):
        self.client = mcp_client
        self.available_tools = self.discover_tools()
    
    def discover_tools(self):
        """Discover available RAG tools and their capabilities."""
        tools = self.client.list_tools()
        rag_tools = [t for t in tools if t.name.startswith("rag_")]
        return {tool.name: tool.inputSchema for tool in rag_tools}
    
    def adaptive_search(self, query):
        """Intelligently orchestrate multiple tools based on query complexity."""
        
        # Analyze query complexity
        if self.is_simple_query(query):
            # Single method suffices
            return self.client.call_tool("rag_semantic_search", {
                "query": query,
                "return_chunks": False,
                "return_answer": True
            })
        
        elif self.is_comparison_query(query):
            # Multi-method approach
            return self.comparison_workflow(query)
        
        else:
            # Full orchestration
            return self.complex_workflow(query)
    
    def comparison_workflow(self, query):
        """Handle comparison queries with multi-method retrieval."""
        # Extract comparison entities
        entities = self.extract_entities(query)
        
        # Search for each entity
        all_chunks = []
        for entity in entities:
            result = self.client.call_tool("rag_semantic_search", {
                "query": f"{query} {entity}",
                "return_chunks": True,
                "return_answer": False
            })
            all_chunks.extend(result["data"]["chunks"])
        
        # Generate comparative answer
        return self.client.call_tool("rag_generator", {
            "query": query,
            "chunks": all_chunks,
            "return_chunks": False,
            "return_answer": True
        })
```

### Adaptive Data Handling

```python
def handle_tool_response(response):
    """Adaptively handle any tool response format."""
    data = response.get("data", {})
    
    # Extract available information
    result = {
        "version": data.get("version", "unknown"),
        "metrics": data.get("metrics", {}),
        "has_chunks": "chunks" in data,
        "has_answer": "answer" in data,
        "has_error": "error" in data
    }
    
    # Add content if available
    if result["has_chunks"]:
        result["chunks"] = normalize_chunks(data["chunks"])
    if result["has_answer"]:
        result["answer"] = data["answer"]
    if result["has_error"]:
        result["error"] = data["error"]
    
    return result

def normalize_chunks(chunks):
    """Normalize chunks to consistent format."""
    normalized = []
    for chunk in chunks:
        if isinstance(chunk, str):
            normalized.append({"text": chunk, "score": 1.0})
        elif isinstance(chunk, dict):
            normalized.append({
                "text": chunk.get("text", str(chunk)),
                "score": chunk.get("score", 1.0),
                "metadata": chunk.get("metadata", {})
            })
    return normalized
```

## Best Practices

### For Developers
1. **Always inspect tool responses** before processing
2. **Handle multiple data formats** gracefully
3. **Cache expensive operations** (indexing, model loading)
4. **Use parallel execution** for independent operations
5. **Implement fallback strategies** for failed tools

### For Agentic Systems
1. **Discover tool capabilities** dynamically
2. **Adapt orchestration** based on query complexity
3. **Monitor performance metrics** to optimize workflows
4. **Handle errors gracefully** with alternative approaches
5. **Learn from successful patterns** to improve future orchestration

## Tool Development Guidelines

When creating new RAG tools:

1. **Follow the template** in `notebook.md`
2. **Use boolean parameters** for maximum flexibility
3. **Return data in your optimal format** - don't force standardization
4. **Include comprehensive metrics** for performance analysis
5. **Handle errors cleanly** with informative messages

## Example Tool Ecosystem

A mature RAG orchestration system might include:

- **Retrievers**: `rag_semantic_search`, `rag_keyword_search`, `rag_hybrid_search`
- **Rerankers**: `rag_cross_encoder_rerank`, `rag_llm_rerank` 
- **Generators**: `rag_local_generator`, `rag_openai_generator`, `rag_claude_generator`
- **Specialized**: `rag_code_search`, `rag_table_search`, `rag_image_search`
- **Evaluators**: `rag_relevance_eval`, `rag_faithfulness_eval`

Each tool focuses on its strength, enabling powerful combinations through intelligent orchestration.
