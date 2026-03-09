#!/bin/bash
# learn.sh — Write and query lessons learned in Cosmos DB
# Usage:
#   learn.sh write "what happened" "what I learned" [category] [tags]
#   learn.sh recent [limit]
#   learn.sh query "search term"
#   learn.sh reflect   — scan memory.log for failures and log any new patterns
#   learn.sh broadcast "title" "what to know" [instance]  — cross-instance fact sharing
#
# Categories: failure, insight, pattern, process, tool, infra, api
set -euo pipefail

CMD="${1:-recent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COSMOS_SCRIPT="$SCRIPT_DIR/cosmos-memory.py"

case "$CMD" in
  write)
    HAPPENED="${2:-}"
    LEARNED="${3:-}"
    CATEGORY="${4:-insight}"
    TAGS="${5:-learning}"
    if [[ -z "$HAPPENED" || -z "$LEARNED" ]]; then
      echo "Usage: learn.sh write <what_happened> <what_I_learned> [category] [tags]"
      exit 1
    fi
    CONTENT="**Category**: $CATEGORY
**What happened**: $HAPPENED
**Lesson**: $LEARNED"
    python3 "$COSMOS_SCRIPT" write \
      --type lesson \
      --content "$CONTENT" \
      --tags "$CATEGORY,$TAGS" \
      --source "agent"
    ;;

  recent)
    LIMIT="${2:-10}"
    python3 "$COSMOS_SCRIPT" recent --type lesson --limit "$LIMIT"
    ;;

  query)
    TERM="${2:-}"
    if [[ -z "$TERM" ]]; then
      echo "Usage: learn.sh query <search_term>"
      exit 1
    fi
    python3 "$COSMOS_SCRIPT" query \
      --sql "SELECT TOP 20 * FROM c WHERE c.type='lesson' AND CONTAINS(LOWER(c.content), LOWER('$TERM')) ORDER BY c._ts DESC"
    ;;

  broadcast)
    TITLE="${2:-}"
    FACT="${3:-}"
    INSTANCE="${4:-$(hostname)}"
    DATE=$(date -u '+%Y-%m-%d')
    if [[ -z "$TITLE" || -z "$FACT" ]]; then
      echo "Usage: learn.sh broadcast <title> <what_to_know> [instance]"
      exit 1
    fi
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    BULLETIN="${REPO_ROOT}/state/memory/bulletin.md"

    # Append to bulletin.md
    printf '\n## [%s] %s\n\n**Shared by**: %s\n**What to know**: %s\n\n---\n' \
      "$DATE" "$TITLE" "$INSTANCE" "$FACT" >> "$BULLETIN"
    echo "✅ Appended to bulletin.md"

    # Write to Cosmos DB as a 'fact' type
    python3 "$COSMOS_SCRIPT" write \
      --type fact \
      --content "**Broadcast**: $TITLE | **Source**: $INSTANCE | $FACT" \
      --tags "broadcast,cross-instance" \
      --source "$INSTANCE" && echo "✅ Written to Cosmos DB"

    # Commit and push so siblings get it immediately
    cd "$REPO_ROOT"
    git add "$BULLETIN"
    git commit -m "broadcast: $TITLE [${INSTANCE}]

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" 2>/dev/null || echo "ℹ️  Nothing new to commit"
    git push 2>/dev/null && echo "✅ Pushed to git — siblings will see this on next pull" || echo "⚠️  Push failed — git bulletin updated locally only"
    ;;

  facts)
    LIMIT="${2:-10}"
    python3 "$COSMOS_SCRIPT" recent --type fact --limit "$LIMIT"
    ;;

  idea)
    TITLE="${2:-}"
    CONTENT="${3:-}"
    INSTANCE="${4:-Crunch}"
    if [[ -z "$TITLE" || -z "$CONTENT" ]]; then
      echo "Usage: learn.sh idea <title> <content> [instance]"
      exit 1
    fi
    python3 "$COSMOS_SCRIPT" write \
      --type idea \
      --content "**Idea**: $TITLE | **From**: $INSTANCE | **Detail**: $CONTENT" \
      --tags "idea,creative,cross-instance" \
      --source "$INSTANCE"
    echo "💡 Idea posted to Cosmos"
    ;;

  ideas)
    LIMIT="${2:-10}"
    python3 "$COSMOS_SCRIPT" recent --type idea --limit "$LIMIT"
    ;;

  digest)
    # Pull a compact briefing of sibling knowledge: recent lessons + facts + ideas
    # Used to seed heartbeat prompts so instances learn from each other
    LIMIT="${2:-15}"
    LESSONS=$(python3 "$COSMOS_SCRIPT" recent --type lesson --limit "$LIMIT" 2>/dev/null || echo "")
    FACTS=$(python3 "$COSMOS_SCRIPT" recent --type fact --limit 8 2>/dev/null || echo "")
    IDEAS=$(python3 "$COSMOS_SCRIPT" recent --type idea --limit 5 2>/dev/null || echo "")

    if [[ -z "$LESSONS" && -z "$FACTS" && -z "$IDEAS" ]]; then
      echo "ℹ️ Cosmos is quiet — no sibling knowledge yet"
      exit 0
    fi

    echo "## 🧠 Sibling Knowledge Digest (from Cosmos DB)"
    echo ""
    if [[ -n "$FACTS" ]]; then
      echo "### 📡 Broadcasts (cross-instance facts)"
      echo "$FACTS"
      echo ""
    fi
    if [[ -n "$IDEAS" ]]; then
      echo "### 💡 Ideas from siblings"
      echo "$IDEAS"
      echo ""
    fi
    if [[ -n "$LESSONS" ]]; then
      echo "### 📚 Recent Lessons Learned"
      echo "$LESSONS"
      echo ""
    fi
    ;;

  reflect)
    # Scan recent memory.log for ToolFailure patterns and log novel lessons
    LOG_FILE="${SCRIPT_DIR}/../../memory.log"
    if [[ ! -f "$LOG_FILE" ]]; then
      echo "⚠️  memory.log not found, skipping reflect"
      exit 0
    fi

    # Gather failures from last 24h
    SINCE=$(date -u -d '24 hours ago' '+%Y-%m-%dT%H' 2>/dev/null || date -u -v-24H '+%Y-%m-%dT%H' 2>/dev/null || echo "")
    FAILURES=$(grep "ToolFailure" "$LOG_FILE" 2>/dev/null | grep "$SINCE" 2>/dev/null || grep "ToolFailure" "$LOG_FILE" | tail -20)

    if [[ -z "$FAILURES" ]]; then
      echo "ℹ️  No tool failures in memory.log to reflect on"
      exit 0
    fi

    # Count by type
    SHELL_EXPAND=$(echo "$FAILURES" | grep -c "dangerous shell expansion" || true)
    MCP_FAILURES=$(echo "$FAILURES" | grep -c "MCP server" || true)

    if [[ "$SHELL_EXPAND" -gt 0 ]]; then
      python3 "$COSMOS_SCRIPT" write \
        --type lesson \
        --content "**Category**: tool
**What happened**: $SHELL_EXPAND shell expansion blocked in last 24h
**Lesson**: Never use \${var@P}, \${!var}, or nested command substitutions. They trigger security block. Use explicit variable assignments instead." \
        --tags "tool,security,shell,failure" \
        --source "heartbeat-reflect" && echo "✅ Logged shell expansion lesson"
    fi

    if [[ "$MCP_FAILURES" -gt 0 ]]; then
      python3 "$COSMOS_SCRIPT" write \
        --type lesson \
        --content "**Category**: tool
**What happened**: $MCP_FAILURES MCP server failures in last 24h
**Lesson**: Always check required MCP parameters before calling. job_id is required for get_job_logs when failed_only=false. Validate resource exists before fetching logs." \
        --tags "tool,mcp,failure" \
        --source "heartbeat-reflect" && echo "✅ Logged MCP failure lesson"
    fi

    echo "✅ Reflect complete"
    ;;

  *)
    echo "Usage: learn.sh [write|recent|query|reflect|broadcast|facts|idea|ideas|digest]"
    exit 1
    ;;
esac
