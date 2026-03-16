# RAG MCP Project Context

## Project Overview
**ragmcp** - A composable RAG (Retrieval-Augmented Generation) orchestration system built with MCP (Model Context Protocol) for educational and experimental purposes.

## Current Architecture
- **FastMCP Server** (`server.py`) - Orchestrates RAG workflows via notebook execution
- **Notebook Workers** (`workers/`) - Individual RAG implementations as executable notebooks
- **MCP Tools** (`mcptools/`) - Tool definitions in markdown files that map to notebook workers
- **Orchestration Patterns** - Composable approach to combining different RAG methods
- **Learning Focus** - Educational environment for experimenting with RAG strategies

## Key Technologies
- **FastMCP** - For MCP server implementation
- **Papermill** - For notebook parameterization and execution
- **Scrapbook** - For extracting results from executed notebooks
- **Jupyter Notebooks** - For implementing individual RAG workers
- **Markdown-driven Tools** - Tool definitions in `mcptools/` folder

## Current Status
- ✅ Basic FastMCP server structure established
- ✅ Notebook execution pipeline working
- ✅ Tool registration from markdown files
- ✅ Demo notebook showing orchestration patterns
- 🔄 **Currently working on**: Improving project organization and AI assistance patterns

## Project Goals
1. **Composable RAG Architecture** - Mix and match different RAG approaches
2. **Educational Value** - Clear patterns for learning RAG orchestration
3. **Experimental Platform** - Easy to test new RAG methods as notebooks
4. **MCP Best Practices** - Demonstrate effective MCP tool design

## Design Principles
- **Modularity** - Each RAG method is an independent notebook
- **Composability** - Tools can be chained and combined
- **Transparency** - Clear data flow and intermediate results
- **Flexibility** - Support different output formats and use cases
