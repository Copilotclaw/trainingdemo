# Server.py Documentation

## Overview

The `server.py` file implements a FastMCP server that orchestrates RAG (Retrieval-Augmented Generation) workers through notebook execution. This learning environment demonstrates how to expose notebook-based RAG implementations as proper MCP tools.

**MAJOR UPDATE (2025-08-13)**: Server now uses **markdown-driven tool configuration** instead of hardcoded tool definitions.

## Current Architecture (Updated)

### Core Components

1. **FastMCP Server**: Handles MCP protocol communication
2. **Tool Loader System**: Dynamic tool registration from markdown definitions
3. **Internal Helper**: `_run_worker()` function for notebook execution
4. **MCP Tools**: Dynamically loaded from `mcptools/*.md` files
5. **Papermill Integration**: Executes notebooks with parameter injection
6. **Scrapbook Integration**: Extracts structured results from notebooks

### File Structure

```
server.py                 # MCP server with dynamic tool loading
tool_loader.py           # Markdown-driven tool configuration system
mcptools/               # Tool definitions (NEW)
  *.md                  # Individual tool definitions with YAML frontmatter
workers/
  rag_hello_one_mcp.ipynb # Basic semantic search implementation
  rag_hello_two_mcp.ipynb # Enhanced search with analytics
raglearning/           # Additional notebooks directory
  naive_rag.ipynb      # Learning-focused RAG implementation
```

## Tool Configuration System (NEW)

### Markdown-Driven Tool Definitions

Tools are now defined in `mcptools/*.md` files with YAML frontmatter:

```yaml
---
name: rag_semantic_search
version: "1.0"
notebook: workers/rag_hello_one_mcp.ipynb
category: basic
description: "Semantic search using RAG pipeline"
tags: [semantic, embedding, similarity]
parameters:
  query:
    type: str
    required: true
    description: "Search query text"
  return_chunks:
    type: bool
    default: false
    description: "Return relevant text chunks"
---

# Tool Documentation

This tool performs semantic search using embeddings...
```

### Tool Types Supported

1. **Notebook-based tools**: Execute Jupyter notebooks via Papermill
2. **Utility tools**: Built-in functions (e.g., `list_workers`)

## How to Register a New RAG Notebook Tool (Updated)

### Step 1: Create Your RAG Notebook

Create a new notebook in the `workers/` or `raglearning/` directory following this structure:

```python
# Cell 1: Parameters (MUST have "tags": ["parameters"])
query = "default query"
return_chunks = True   # Return relevant text chunks
return_answer = True   # Return generated answer
reindex = False        # Rebuild search index

# Cell 2: RAG Implementation
# Your retrieval and generation logic here

# Cell 3: Output via Scrapbook
import scrapbook as sb
sb.glue("answer", your_answer)      # Only if return_answer=True
sb.glue("chunks", your_chunks)      # Only if return_chunks=True
sb.glue("metrics", your_metrics)
```

### Step 2: Create Tool Definition (NEW)

Create a markdown file in `mcptools/` directory:

**mcptools/my_new_tool.md**:
```yaml
---
name: my_new_tool
version: "1.0"
notebook: workers/my_notebook.ipynb
category: custom
description: "My custom RAG implementation"
tags: [custom, rag]
parameters:
  query:
    type: str
    required: true
    description: "Search query"
  custom_param:
    type: int
    default: 5
    description: "Custom parameter"
---

# My New Tool

This tool implements a custom RAG approach...

## Usage Examples

```bash
# Call via MCP client
await client.call_tool("my_new_tool", {
    "query": "What is AI?",
    "custom_param": 10
})
```
```

### Step 3: Tool Auto-Registration

The tool will be automatically registered when the server starts - no code changes needed!

## Issues Resolved (2025-08-13)

### ✅ Path Resolution Issues
- **Problem**: Client failed when VS Code started from different directories
- **Solution**: Used `Path(__file__).parent` for absolute path resolution
- **Files**: `simple_client.py`, `server.py`, `tool_loader.py`

### ✅ Unicode Encoding Issues  
- **Problem**: Windows terminal couldn't display emoji characters
- **Solution**: Replaced all emojis with text-based status indicators
- **Files**: `server.py`, `tool_loader.py`, `simple_client.py`

### ✅ FastMCP Parameter Handling
- **Problem**: `**kwargs` not supported in FastMCP tool functions
- **Solution**: Explicit parameter definitions based on YAML frontmatter
- **Impact**: All tools now properly register and expose correct schemas

### ✅ Dynamic Tool Loading
- **Problem**: Hardcoded tool definitions in server.py
- **Solution**: Markdown-driven configuration with YAML frontmatter
- **Benefit**: Easy tool addition without code changes

## Known Issues & TODO (for tomorrow)

### 🔶 Error Handling
- **Server**: Needs comprehensive error handling in `_run_worker()`
- **Tool Loader**: Needs robust error handling for malformed markdown files
- **Client**: Needs better connection error handling
- **Priority**: HIGH - affects reliability

### 🔶 Tool Validation
- **Schema Validation**: YAML frontmatter validation
- **Parameter Validation**: Type checking before notebook execution  
- **Notebook Validation**: Check if notebook files exist
- **Priority**: MEDIUM - improves user experience

### 🔶 Logging System
- **Structured Logging**: Replace print statements with proper logging
- **Log Levels**: DEBUG, INFO, WARN, ERROR
- **Log Files**: Persistent logging for debugging
- **Priority**: LOW - nice to have

## Architecture Benefits

1. **Separation of Concerns**: Configuration separate from implementation
2. **Easy Maintenance**: Add tools without touching server code
3. **Documentation**: Markdown content serves as built-in documentation
4. **Version Control**: Tool definitions can be tracked separately
5. **Flexibility**: Supports both notebook and utility tools

Add a new `@mcp.tool()` function:

```python
@mcp.tool()
def your_rag_method(query: str, return_chunks: bool = True, return_answer: bool = True, reindex: bool = False) -> dict:
    """
    Your RAG method description here.
  
    Args:
        query: The search query or question to process
        return_chunks: If True, return relevant text chunks
        return_answer: If True, return generated answer
        reindex: Whether to rebuild the search index
  
    Returns:
        dict: Contains requested outputs based on flags:
            - answer: Generated response (if return_answer=True)
            - chunks: Relevant text chunks (if return_chunks=True)
            - metrics: Performance metrics (always included)
    """
    return _run_worker("your_notebook_name.ipynb", {
        "query": query, 
        "return_chunks": return_chunks,
        "return_answer": return_answer,
        "reindex": reindex
    })
```

### Step 3: Test Your Tool

1. **Notebook testing**: `python rag_mcp_clean.ipynb`
2. **Stdio testing**: `python simple_client.py`
3. **Manual testing**: Import server and call tools directly
