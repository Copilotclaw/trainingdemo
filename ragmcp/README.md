# RAG + MCP Learning System

A composable RAG (Retrieval-Augmented Generation) orchestration system built with MCP (Model Context Protocol) for educational and experimental purposes.

## 🎯 What This Is

This is a **learning and experimentation environment** that demonstrates how to build composable RAG systems using modern MCP patterns. Think of it as a "laboratory" for exploring different RAG approaches and orchestration strategies.

## 📚 Documentation

- **[`notebook.md`](notebook.md)** - Template for creating new RAG notebooks
- **[`orchestration.md`](orchestration.md)** - Advanced patterns for combining RAG tools  
- **[`server.md`](server.md)** - MCP server architecture and tool registration

## 🕸️ Graph RAG

The [`GraphRAG/`](GraphRAG/) folder contains a standalone Graph RAG demo using historical data and local Ollama LLMs.

| Resource | Link |
|----------|------|
| 📓 Notebook | [`GraphRAG/Historical_GraphRAG_Demo - Copy.ipynb`](GraphRAG/Historical_GraphRAG_Demo%20-%20Copy.ipynb) |
| 📖 Explainer | **[Graph RAG Explainer](https://htmlpreview.github.io/?https://github.com/Copilotclaw/trainingdemo/blob/main/ragmcp/GraphRAG/graph-rag-explainer.html)** — domain keywords, embeddings, two-phase retrieval |

The explainer covers:
- What Graph RAG is and why classical RAG fails multi-hop questions
- Why domain-specific keywords (e.g. `radioactivity research`, `heliocentrism`) are powerful anchors
- How semantic embeddings fix brittle keyword matching
- How Graph RAG + embeddings work as a two-phase hybrid retrieval architecture

## 🏗️ Project Structure

```
├── server.py                          # MCP server with RAG tools
├── rag_mcp_orchestrator_demo.ipynb   # Demo showing tool usage
├── workers/                           # RAG implementation notebooks
│   ├── rag_hello_one_mcp.ipynb       # Basic semantic search
│   └── rag_hello_two_mcp.ipynb       # Enhanced search with metadata
├── runs/                              # Executed notebooks (preserved for inspection)
├── data/                              # Sample corpus data
└── mcptools/                          # MCP tool definitions (markdown-driven)
    ├── list_workers.md                # List available RAG notebooks
    ├── rag_semantic_search.md         # Basic semantic search tool
    ├── rag_enhanced_search.md         # Enhanced search with metadata
    └── rag_learning_search.md         # Learning-focused search tool
```

## 🚀 Quick Start

### 1. Demo the System
```jupyter
# Open and run the main demo
rag_mcp_orchestrator_demo.ipynb
```

### 2. Test MCP Tools
```python
# Run the MCP server
python server.py

# Or use the test client
python simple_client.py
```

### 3. Create New RAG Method
1. Copy the template from `notebook.md`
2. Implement your RAG approach in `workers/`
3. Add tool definition in `mcptools/` as a markdown file
4. The server will automatically load it via `tool_loader.py`

## 🔧 Key Features

### Composable Architecture
- **Simple Tools**: Each RAG method is a focused tool
- **Boolean Control**: Precise output control with `return_chunks`/`return_answer`
- **Flexible Data**: Tools return adaptable JSON structures
- **Orchestration Ready**: Combine tools for complex workflows

### Learning-Friendly
- **Template-Driven**: Standard structure for new implementations
- **Execution Traces**: Notebooks saved in `runs/` for inspection
- **Rich Documentation**: Comprehensive guides and patterns
- **Debug Support**: Full parameter injection and output tracing

### Modern MCP Patterns
- **FastMCP Integration**: Proper tool definitions with schema
- **Markdown-Driven Tools**: Tool definitions in `mcptools/*.md` with YAML frontmatter
- **Dynamic Loading**: Automatic tool registration from markdown files
- **Standard Protocol**: Compatible with MCP ecosystem

## 🎓 Educational Use Cases

### For Students
- Learn modern RAG architectures
- Experiment with different retrieval methods
- Practice MCP tool development
- Build orchestration workflows

### For Researchers  
- Prototype new RAG approaches
- Compare method performance
- Develop novel orchestration patterns
- Share reproducible experiments

### For Developers
- Understand composable AI architectures  
- Learn MCP best practices
- Build production-ready patterns
- Design tool ecosystems

## 🔄 Orchestration Examples

### Multi-Method Fusion
```python
# Combine semantic + enhanced search
semantic_chunks = rag_semantic_search(query, return_chunks=True, return_answer=False)
enhanced_chunks = rag_enhanced_search(query, return_chunks=True, return_answer=False)
combined_result = combine_results(semantic_chunks, enhanced_chunks)
```

### Query Decomposition
```python
# Break complex queries into parts
sub_queries = decompose_query(complex_query)
all_chunks = []
for sub_query in sub_queries:
    chunks = rag_semantic_search(sub_query, return_chunks=True, return_answer=False)
    all_chunks.extend(chunks)
final_answer = generate_answer(complex_query, chunks=all_chunks)
```

## 🛠️ Technical Implementation

### MCP Server Architecture
- **server.py**: Main MCP server with FastMCP framework
- **tool_loader.py**: Dynamic tool loading from markdown definitions
- **simple_client.py**: Test client for validation
- **mcptools/**: Markdown files with YAML frontmatter defining tools

### Key Technologies
- **FastMCP 2.11.3**: MCP server framework
- **Papermill**: Notebook execution engine
- **Scrapbook**: Result extraction from notebooks
- **python-frontmatter**: YAML frontmatter parsing
- **Windows PowerShell**: Development environment

## 🐛 Known Issues & Solutions

### Path Resolution
- **Issue**: VS Code directory context unreliable
- **Solution**: Use `Path(__file__).parent` for absolute paths

### Unicode Encoding
- **Issue**: Windows PowerShell crashes on emoji output
- **Solution**: Replace emojis with `[STATUS]` text format

### FastMCP Parameters
- **Issue**: FastMCP rejects `**kwargs` in tool functions
- **Solution**: Use explicit parameter functions with proper typing

## 🎯 Next Steps

This system provides the foundation for exploring advanced RAG concepts:

- **Hybrid Search**: Combine semantic, keyword, and graph-based retrieval
- **Adaptive RAG**: Dynamic method selection based on query characteristics  
- **Multi-Stage Processing**: Iterative refinement and verification
- **Agentic Workflows**: LLM-driven orchestration of multiple tools
- **Error Handling**: Robust error handling improvements (planned)

## 📈 Development Status

- ✅ **Working MCP Server**: 5 tools registered and functional
- ✅ **Client-Server Communication**: stdio transport working
- ✅ **Dynamic Tool Loading**: Markdown-driven configuration
- ✅ **Path Resolution**: Windows compatibility achieved
- ✅ **Unicode Handling**: Emoji-safe output implemented
- 🔄 **Error Handling**: Planned improvements for robustness

Happy experimenting! 🚀
