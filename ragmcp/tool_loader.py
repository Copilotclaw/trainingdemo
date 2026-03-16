"""
Tool loader for MCP tools defined in markdown files with YAML frontmatter.
"""

import frontmatter
from pathlib import Path
from typing import Dict, List, Callable
from fastmcp import FastMCP

def load_tools_from_directory(tools_dir: Path) -> List[Dict]:
    """Load all tool definitions from markdown files"""
    tools = []
    if not tools_dir.exists():
        print(f"[WARN] Tools directory not found: {tools_dir}")
        return tools
        
    for md_file in tools_dir.glob("*.md"):
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                post = frontmatter.load(f)
                tool_def = {
                    **post.metadata,
                    'description_md': post.content,
                    'source_file': md_file.name
                }
                tools.append(tool_def)
                print(f"[OK] Loaded tool definition: {tool_def.get('name', md_file.stem)}")
        except Exception as e:
            print(f"[ERROR] Failed to load {md_file}: {e}")
            
    print(f"[LOADED] Loaded {len(tools)} tool definitions from {tools_dir}")
    return tools

def create_mcp_tool_from_definition(mcp: FastMCP, tool_def: Dict, run_worker_func: Callable) -> None:
    """Create MCP tool from markdown definition"""
    tool_name = tool_def.get('name')
    if not tool_name:
        print(f"[ERROR] Tool definition missing 'name' field")
        return
        
    description = tool_def.get('description', f"Tool: {tool_name}")
    version = tool_def.get('version', '1.0.0')
    notebook_path = tool_def.get('notebook_path') or tool_def.get('notebook')
    
    # Handle list_workers utility tool
    if tool_name == 'list_workers':
        @mcp.tool(description=description)
        def list_workers(subdir: str = "workers") -> dict:
            try:
                workers_dir = Path(__file__).parent / subdir
                if workers_dir.exists():
                    notebooks = list(workers_dir.glob("*.ipynb"))
                    return {
                        "status": "success",
                        "workers": [nb.name for nb in notebooks],
                        "count": len(notebooks),
                        "directory": str(workers_dir),
                        "version": version
                    }
                else:
                    return {
                        "status": "error",
                        "error": f"Directory not found: {workers_dir}",
                        "version": version
                    }
            except Exception as e:
                return {"status": "error", "error": str(e), "version": version}
    
    elif notebook_path and notebook_path != 'null':
        # Create notebook-based tool based on parameters
        if tool_name == 'rag_semantic_search':
            @mcp.tool(description=description)
            async def rag_semantic_search(query: str, return_chunks: bool = False) -> dict:
                try:
                    kwargs = {"query": query, "return_chunks": return_chunks}
                    result = await run_worker_func(notebook_path, kwargs)
                    return result
                except Exception as e:
                    return {"status": "error", "error": str(e), "version": version}
        
        elif tool_name == 'rag_enhanced_search':
            @mcp.tool(description=description)
            async def rag_enhanced_search(query: str, similarity_threshold: float = 0.7, return_chunks: bool = False) -> dict:
                try:
                    kwargs = {"query": query, "similarity_threshold": similarity_threshold, "return_chunks": return_chunks}
                    result = await run_worker_func(notebook_path, kwargs)
                    return result
                except Exception as e:
                    return {"status": "error", "error": str(e), "version": version}
        
        elif tool_name == 'rag_learning_search':
            @mcp.tool(description=description)
            async def rag_learning_search(query: str, max_results: int = 5) -> dict:
                try:
                    kwargs = {"query": query, "max_results": max_results}
                    result = await run_worker_func(notebook_path, kwargs)
                    return result
                except Exception as e:
                    return {"status": "error", "error": str(e), "version": version}
        
        else:
            print(f"[ERROR] Unknown tool type: {tool_name}")
            return
    else:
        print(f"[ERROR] Tool {tool_name} missing notebook path")
        return
    
    print(f"[REGISTER] Registered MCP tool: {tool_name}")

def register_tools_from_directory(mcp: FastMCP, tools_dir: Path, run_worker_func: Callable) -> int:
    """Load and register all tools from markdown definitions"""
    print(f"[SEARCH] Loading tools from: {tools_dir}")
    tool_definitions = load_tools_from_directory(tools_dir)
    
    registered_count = 0
    for tool_def in tool_definitions:
        try:
            create_mcp_tool_from_definition(mcp, tool_def, run_worker_func)
            registered_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to register tool {tool_def.get('name', 'unknown')}: {e}")
    
    print(f"[SUCCESS] Successfully registered {registered_count} MCP tools")
    return registered_count