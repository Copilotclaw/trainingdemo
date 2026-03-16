from fastmcp import FastMCP
import papermill as pm
import scrapbook as sb
from pathlib import Path
import tempfile
from tool_loader import register_tools_from_directory

# Get the directory where this server.py file is located
SERVER_DIR = Path(__file__).parent

mcp = FastMCP("rag-notebook-orchestrator")

# Internal helper function - not exposed as MCP tool
def _run_worker(notebook_path: str, parameters: dict) -> dict:
    """Internal helper to execute notebooks via Papermill and extract results
    
    Args:
        notebook_path: Path to notebook relative to SERVER_DIR (e.g., "workers/rag_hello_one_mcp.ipynb")
        parameters: Parameters to pass to the notebook
        
    Returns:
        dict: Standardized data object containing:
            - version: Tool version identifier
            - metrics: Performance metrics
            - error: Error message if execution failed
            - Additional fields based on notebook implementation
    """
    nb_in = SERVER_DIR / notebook_path
    out = SERVER_DIR / "runs" / f"{nb_in.stem}_out.ipynb"
    
    # Ensure runs directory exists
    out.parent.mkdir(exist_ok=True)
    
    print(f"[DEBUG] Executing {notebook_path} with parameters: {parameters}")
    print(f"[DEBUG] Server dir: {SERVER_DIR}")
    print(f"[DEBUG] Input notebook: {nb_in}")
    print(f"[DEBUG] Output notebook: {out}")
    
    try:
        # Check if input notebook exists
        if not nb_in.exists():
            error_msg = f"Notebook not found: {nb_in}"
            print(f"❌ ERROR: {error_msg}")
            return {
                "version": "server@v1.0",
                "error": error_msg,
                "metrics": {"execution_time": 0, "status": "failed"}
            }
        
        # Execute notebook via Papermill
        pm.execute_notebook(str(nb_in), str(out), parameters=parameters, kernel_name="python3")
        
        # Extract results via scrapbook
        nb = sb.read_notebook(str(out))
        result = nb.scraps.get("data", {}).data if "data" in nb.scraps else {}
        
        # Ensure result is a dict and has required fields
        if not isinstance(result, dict):
            result = {"raw_result": result}
            
        # Add server metadata if not present
        if "version" not in result:
            result["version"] = f"server@v1.0-{nb_in.stem}"
        if "metrics" not in result:
            result["metrics"] = {"status": "completed"}
            
        print(f"📊 DEBUG: Extracted data: {result}")
        print(f"💾 DEBUG: Executed notebook saved to: {out}")
        return result
        
    except Exception as e:
        error_msg = f"Notebook execution failed: {str(e)}"
        print(f"❌ ERROR: {error_msg}")
        
        # Return standardized error response
        error_result = {
            "version": f"server@v1.0-{nb_in.stem}",
            "error": error_msg,
            "metrics": {
                "execution_time": 0,
                "status": "failed",
                "error_type": type(e).__name__
            }
        }
        
        return error_result

# Load and register tools from markdown definitions
print("[START] Starting server with tool loading...")
tools_dir = SERVER_DIR / "mcptools"
print(f"[TOOLS] Looking for tools in: {tools_dir}")

# For now, let's add a simple test tool to make sure the server works
@mcp.tool()
def test_tool(message: str = "Hello") -> dict:
    """Simple test tool to verify server functionality"""
    return {
        "version": "test@1.0",
        "message": f"Test response: {message}",
        "metrics": {"status": "ok"}
    }

try:
    from tool_loader import register_tools_from_directory
    num_tools = register_tools_from_directory(mcp, tools_dir, _run_worker)
    print(f"[OK] Successfully loaded {num_tools} tools")
except Exception as e:
    print(f"[ERROR] Failed to load tools: {e}")
    import traceback
    traceback.print_exc()
    print("[WARN] Continuing with test tool only...")

if __name__ == "__main__":
    print("[TARGET] Starting MCP server...")
    mcp.run()