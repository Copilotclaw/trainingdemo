# Open Issues & Technical Debt

This document tracks known issues and technical improvements needed in the RAG + MCP learning system.

**MAJOR UPDATE (2025-08-13)**: Resolved path resolution and Unicode issues, added new error handling requirements.

## ✅ RESOLVED ISSUES

### ✅ Path Resolution in Notebooks & Server
**Issue**: Path resolution failed when VS Code started from different directories.
**Resolution**: Implemented `Path(__file__).parent` pattern across all components.
**Status**: COMPLETED ✅
- Server path resolution: ✅ Working with `SERVER_DIR = Path(__file__).parent`
- Client path resolution: ✅ Working with `CLIENT_DIR = Path(__file__).parent`
- Tool loader path resolution: ✅ Working for all file operations

### ✅ Unicode Encoding Issues  
**Issue**: Windows terminal couldn't display emoji characters, causing server crashes.
**Resolution**: Replaced all emojis with text-based status indicators.
**Status**: COMPLETED ✅
- Server output: ✅ All [STATUS] format
- Client output: ✅ All [STATUS] format  
- Tool loader output: ✅ All [STATUS] format

### ✅ FastMCP Parameter Handling
**Issue**: `**kwargs` not supported in FastMCP tool functions.
**Resolution**: Explicit parameter definitions based on YAML frontmatter.
**Status**: COMPLETED ✅
- All tools register successfully
- Proper parameter schemas exposed
- Type validation working

### ✅ Dynamic Tool Loading
**Issue**: Hardcoded tool definitions made maintenance difficult.
**Resolution**: Markdown-driven configuration with YAML frontmatter.
**Status**: COMPLETED ✅
- Tools defined in `mcptools/*.md` files
- Automatic registration on server startup
- Easy addition of new tools

---

## 🔶 HIGH PRIORITY - Error Handling (TODO TOMORROW)

### Server Error Handling
**Issue**: `_run_worker()` function needs comprehensive error handling.
**Current Status**: Basic try-catch but not following standardized format.

**Required Improvements**:
```python
async def _run_worker(notebook_path: str, parameters: dict) -> dict:
    try:
        # Current implementation
        return result
    except FileNotFoundError as e:
        return {"status": "error", "error": f"Notebook not found: {notebook_path}", "error_type": "file_error"}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "error": f"Notebook execution failed: {e}", "error_type": "execution_error"}
    except Exception as e:
        return {"status": "error", "error": str(e), "error_type": "unknown_error"}
```

### Tool Loader Error Handling  
**Issue**: Tool loader needs robust error handling for malformed markdown files.
**Current Status**: Basic try-catch but incomplete.

**Required Improvements**:
- YAML frontmatter validation
- Parameter schema validation  
- Notebook file existence checking
- Graceful degradation for malformed tools

### Client Error Handling
**Issue**: Client needs better connection error handling.
**Current Status**: Basic error display but not user-friendly.

**Required Improvements**:
- Retry logic for connection failures
- Better error messages for common issues
- Graceful handling of server crashes

---

## � MEDIUM PRIORITY - Validation & Robustness

### Tool Definition Validation
**Issue**: Need schema validation for YAML frontmatter in tool definitions.
**Current Status**: No validation - malformed YAML can cause silent failures.

**Required Features**:
- JSON Schema validation for YAML frontmatter
- Parameter type validation
- Required field checking
- Helpful error messages for common mistakes

### Notebook Parameter Validation
**Issue**: Parameters passed to notebooks should be validated before execution.
**Current Status**: Parameters passed directly to Papermill without validation.

**Required Features**:
- Type checking based on tool definition parameters
- Range validation for numeric parameters
- Required parameter enforcement
- Default value handling

### File System Validation
**Issue**: Tool loader should validate notebook file existence.
**Current Status**: Tools register even if notebook files don't exist.

**Required Features**:
- Notebook file existence checking during tool registration
- Path validation for relative paths
- Warning messages for missing files
- Graceful handling of missing notebooks

---

## 🔶 LOW PRIORITY - Quality of Life Improvements

### Logging System
**Issue**: Replace print statements with structured logging.
**Current Status**: Using print statements throughout.

**Desired Features**:
- Structured logging with levels (DEBUG, INFO, WARN, ERROR)
- Log file output for debugging
- Configurable log levels
- Request/response logging for MCP calls

### Performance Monitoring
**Issue**: Add performance metrics and monitoring.
**Current Status**: Basic timing in notebooks only.

**Desired Features**:
- Tool execution timing
- Memory usage monitoring
- Error rate tracking
- Performance dashboard

### Development Tools
**Issue**: Need better development and debugging tools.
**Current Status**: Manual testing only.

**Desired Features**:
- Unit tests for tool loader
- Integration tests for server
- Mock MCP client for testing
- Hot reload for tool definitions

---

## �📊 Data File Management

**Issue**: Need sample data files for realistic RAG implementations.

**Current Status**: Basic `data/corpus.jsonl` placeholder exists

**Requirements**:
- Sample corpus data for semantic search demos
- Different data formats (JSON, text, CSV) for various RAG approaches
- Small enough for learning/demo purposes but realistic enough to be useful

**Action Items**:
1. Create sample corpus data with ML/AI content
2. Add data loading utilities to template
3. Document data format expectations

---

## 🎯 TOMORROW'S FOCUS

### Priority 1: Server Error Handling
- Implement comprehensive error handling in `_run_worker()`
- Follow standardized error response format from notebook.md
- Add proper exception categorization

### Priority 2: Tool Loader Robustness  
- Add YAML validation
- Implement file existence checking
- Add graceful error handling for malformed tool definitions

### Priority 3: Client Error Handling
- Improve connection error messages
- Add retry logic for transient failures
- Better user experience for common error scenarios

### Testing Plan
- Test error scenarios manually
- Verify error responses follow standard format
- Ensure server doesn't crash on malformed inputs
- Validate error propagation to MCP clients

## 🧪 Testing & Validation

**Issue**: Need systematic testing across different environments and use cases.

**Current Status**: Basic functionality verified locally

**Missing**:
- Automated tests for different environment scenarios
- Performance benchmarking framework
- Validation of orchestration patterns
- Error handling edge cases

**Action Items**:
1. Create test suite for path resolution across environments
2. Add performance measurement framework
3. Test complex orchestration scenarios
4. Document known limitations

---

## 📚 Documentation Completeness

**Issue**: Some advanced patterns need more detailed examples.

**Current Status**: Core documentation complete, advanced patterns documented conceptually

**Missing**:
- Step-by-step implementation examples for each RAG technique
- Troubleshooting guide for common issues
- Performance tuning recommendations
- Best practices for different use cases

**Action Items**:
1. Add implementation walkthroughs for naive, keyword, hybrid RAG
2. Create troubleshooting section
3. Add performance optimization guide
4. Document scaling considerations

---

## 🔮 Future Enhancements

**Potential Improvements** (not blocking current work):

### Enhanced MCP Integration
- Support for MCP resource patterns
- Dynamic tool discovery and registration
- Tool dependency management

### Advanced RAG Techniques
- Multi-modal RAG (text + images)
- Graph-based retrieval
- Adaptive chunking strategies
- Real-time index updates

### Development Experience
- Hot-reload for notebook changes
- Interactive debugging tools
- Visual orchestration designer
- Performance profiling integration

### Production Readiness
- Containerization support
- Scalability patterns
- Monitoring and observability
- Security considerations

---

## 📝 Notes

- This document should be updated as issues are discovered and resolved
- Each issue should include reproduction steps when applicable
- Solutions should be tested across target environments before closing
- Consider impact on learning objectives when prioritizing fixes
