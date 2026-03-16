#!/usr/bin/env python3
"""
Simple FastMCP Stdio Test Client
Tests server.py via stdio transport by listing available tools and their descriptions.
Perfect for testing MCP tool introspection without executing notebooks.
"""
import asyncio
import sys
from pathlib import Path

print("Starting simple_client.py...")

# Get the directory where this client file is located (same as server.py)
CLIENT_DIR = Path(__file__).parent
SERVER_PATH = CLIENT_DIR / "server.py"

print(f"[Client] Client directory: {CLIENT_DIR}")
print(f"[Server] Server path: {SERVER_PATH}")

try:
    from fastmcp import Client
    print("[OK] FastMCP imported successfully")
except ImportError as e:
    print(f"[ERROR] FastMCP import failed: {e}")
    sys.exit(1)

async def main():
    """Main demo function - Test stdio transport by listing tools"""
    print("[TARGET] RAG FastMCP Stdio Test Client")
    print("Connecting to server.py via stdio to test tool introspection...")
    print()
    
    try:
        print("[CONNECT] Attempting stdio connection...")
        # Connect via stdio to server.py using absolute path for reliability
        async with Client(str(SERVER_PATH)) as client:
            print("[OK] Connected successfully!")
            print("=" * 100)
            
            # List available tools with full descriptions
            print("[TOOLS] Available MCP Tools:")
            print("=" * 100)
            tools = await client.list_tools()
            print(f"Found {len(tools)} tools:\n")
            
            for i, tool in enumerate(tools, 1):
                print(f"{i}. [TOOL] Tool: {tool.name}")
                print(f"   [DESC] Description: {tool.description}")
                print(f"   [INPUT] Input Schema: {tool.inputSchema}")
                print("-" * 50)
            
            print("\n[COMPLETE] Stdio connection test complete!")
            print("[SUCCESS] Server is properly exposing tools via MCP protocol!")
            
    except Exception as e:
        print(f"[ERROR] Connection Error: {e}")
        print("[HELP] Make sure server.py is working correctly")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("Running main...")
    asyncio.run(main())
    print("Done.")
