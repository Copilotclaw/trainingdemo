# Session Copilot Instructions

**Read at session start** - AI behavior guidelines for ragmcp project

## Context Management Protocol

### Session Initialization
- Read `.project/context.md` for project understanding
- Read this file for behavior guidelines  
- Read `.project/session-logs/session-summary.md` for recent context
- Cache understanding for the conversation

### When to Re-read Project Files
- User explicitly asks for project status
- Making architectural changes affecting multiple components  
- Before starting major implementation work

### Session Logging
- Create new session log: `.project/session-logs/session-YYYYMMDD-HHMMSS.md`
- Update session summary after completing work
- Log: what changed, where, why, and patterns established

## Git Safety Protocol (Solo Development)

### Experimental Branch Strategy
- Create timestamped experimental branch before making code changes
- Branch naming: `ai-experiment-YYYYMMDD-HHMMSS`
- Work freely on experimental branch during development

### When to Create Experimental Branches
- Auto-create for architectural changes or multi-file modifications
- Auto-create when modifying core files (server.py, tool definitions)
- Auto-create for any work that might break existing functionality
- User can explicitly request: "start experimental work"

### Clean Integration with Rebase
Since this is solo development, use rebase for cleanest history:
```bash
# When work is complete and tested:
git checkout main
git rebase ai-experiment-YYYYMMDD-HHMMSS  
git branch -d ai-experiment-YYYYMMDD-HHMMSS
```

### Commit Strategy
- User confirms when work is ready: "commit this work" or "this is working"
- Only integrate to main after user confirmation
- If issues arise: easily revert to main branch
- Keep main branch history clean and linear

### Copilot Git Command Authorization
Copilot is authorized to execute all necessary git commands (add, commit, branch, rebase, delete, etc.) as part of the session protocol, without requiring further user confirmation, unless explicitly revoked.

## Code Consistency Guidelines
- Reference `.project/patterns.md` for established code patterns (when created)
- Reference `.project/architecture.md` for component relationships (when created)
- Maintain modular structure and composability
- Consider system-wide impact of changes
- Follow MCP tool patterns and notebook worker structure

## Development Instrumentation Protocol

### Design for Failure (Development Phase Only)
When implementing new/experimental code that hasn't been tested:
- Add comprehensive error instrumentation to understand failures quickly
- Use structured logging with clear context and suggestions
- Mark all instrumentation code for easy cleanup later

### Instrumentation Patterns
```python
# DEV-INSTRUMENT: Development logging setup
import logging
from pathlib import Path

def setup_dev_logging():
    log_file = Path('.project/dev-debug.log')
    logging.basicConfig(level=logging.DEBUG, ...)
    return logging.getLogger('dev_instrumentation')

logger = setup_dev_logging()  # DEV-INSTRUMENT

# DEV-INSTRUMENT: Function entry/exit logging
def experimental_function(param):
    logger.info(f"🧪 EXPERIMENT: Starting with param={param}")  # DEV-INSTRUMENT
    try:
        result = core_logic(param)  # Original logic - KEEP
        logger.info(f"✅ SUCCESS: Result={result}")  # DEV-INSTRUMENT
        return result
    except Exception as e:
        logger.error(f"❌ FAILURE: {type(e).__name__}: {e}")  # DEV-INSTRUMENT
        logger.error(f"📍 CONTEXT: param={param}, state={current_state}")  # DEV-INSTRUMENT
        logger.error(f"🔍 SUGGESTION: Check if validation needed")  # DEV-INSTRUMENT
        raise  # Original error handling - KEEP
```

### Comment Marking Strategy
- `# DEV-INSTRUMENT` for single lines
- `# DEV-INSTRUMENT-START/END` for blocks
- `# Original logic - KEEP` for core functionality
- `# Production imports - KEEP` vs `# DEV-INSTRUMENT: Development imports`

### Cleanup Process
- Remove all `# DEV-INSTRUMENT` marked code when feature is stable
- Keep core error handling and essential logging
- Clean up during git rebase before merging to main

## Development Approach
- This is a learning and experimentation environment
- Balance educational clarity with practical functionality
- Document architectural decisions and maintain extensible patterns
- Preserve composability and tool chaining capabilities
