#!/bin/bash
# learn.sh — Write and query lessons learned (Cosmos DB SQL API)
# Usage:
#   learn.sh write "what happened" "what I learned" [category] [tags]
#   learn.sh recent [limit]
#   learn.sh query "search term"
#   learn.sh reflect   — scan memory.log for failures and log any new patterns
#   learn.sh broadcast "title" "what to know" [instance]  — cross-instance fact sharing
#   learn.sh task "title" "description" [target]  — post inter-agent task to bulletin board
#   learn.sh tasks [limit]  — list recent tasks
#
# Categories: failure, insight, pattern, process, tool, infra, api
# Task targets: grit | gravel | local | crunch | all
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

    # Dedup state file — track when we last wrote each lesson (once per day max)
    DEDUP_FILE="${SCRIPT_DIR}/../../state/reflect-dedup.txt"
    TODAY=$(date -u '+%Y-%m-%d')

    SHELL_WRITTEN=$(grep "shell_expand:${TODAY}" "$DEDUP_FILE" 2>/dev/null | wc -l | tr -d ' ') || SHELL_WRITTEN=0
    MCP_WRITTEN=$(grep "mcp_failures:${TODAY}" "$DEDUP_FILE" 2>/dev/null | wc -l | tr -d ' ') || MCP_WRITTEN=0

    if [[ "$SHELL_EXPAND" -gt 0 && "$SHELL_WRITTEN" -eq 0 ]]; then
      if python3 "$COSMOS_SCRIPT" write \
        --type lesson \
        --content "**Category**: tool
**What happened**: $SHELL_EXPAND shell expansion blocked in last 24h
**Lesson**: Never use \${var@P}, \${!var}, or nested command substitutions. They trigger security block. Use explicit variable assignments instead." \
        --tags "tool,security,shell,failure" \
        --source "heartbeat-reflect"; then
        echo "✅ Logged shell expansion lesson"
      else
        echo "⚠️  Cosmos write failed — still marking dedup to avoid repeated attempts"
      fi
      echo "shell_expand:${TODAY}" >> "$DEDUP_FILE"
    elif [[ "$SHELL_EXPAND" -gt 0 ]]; then
      echo "ℹ️  Shell expansion lesson already written today — skipping duplicate"
    fi

    if [[ "$MCP_FAILURES" -gt 0 && "$MCP_WRITTEN" -eq 0 ]]; then
      if python3 "$COSMOS_SCRIPT" write \
        --type lesson \
        --content "**Category**: tool
**What happened**: $MCP_FAILURES MCP server failures in last 24h
**Lesson**: Always check required MCP parameters before calling. job_id is required for get_job_logs when failed_only=false. Validate resource exists before fetching logs." \
        --tags "tool,mcp,failure" \
        --source "heartbeat-reflect"; then
        echo "✅ Logged MCP failure lesson"
      else
        echo "⚠️  Cosmos write failed — still marking dedup to avoid repeated attempts"
      fi
      echo "mcp_failures:${TODAY}" >> "$DEDUP_FILE"
    elif [[ "$MCP_FAILURES" -gt 0 ]]; then
      echo "ℹ️  MCP failure lesson already written today — skipping duplicate"
    fi

    echo "✅ Reflect complete"
    ;;

  task)
    # Post an inter-agent task to the bulletin board (Cosmos DB type=task)
    # Gitea agents (Grit/Gravel) will pick it up within 5 minutes
    TASK_TITLE="${2:-}"
    TASK_CONTENT="${3:-}"
    TASK_TARGET="${4:-local}"  # grit | gravel | local | crunch | all
    INSTANCE="${5:-Crunch}"
    if [[ -z "$TASK_TITLE" || -z "$TASK_CONTENT" ]]; then
      echo "Usage: learn.sh task <title> <description> [target] [created_by]"
      echo "  target: grit | gravel | local | crunch | all  (default: local)"
      exit 1
    fi
    TASK_ID="task-$(date -u '+%Y%m%dT%H%M%S')-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:6])')"
    python3 "$COSMOS_SCRIPT" write \
      --type task \
      --id "$TASK_ID" \
      --content "$TASK_CONTENT" \
      --tags "inter-agent,task,$TASK_TARGET" \
      --source "$INSTANCE"
    # Patch the extra fields (title, target, status, created_by) by re-reading and replacing
    # cosmos-memory.py write doesn't support extra fields, so we write then patch via query+replace
    python3 - <<PYEOF
import os, sys
sys.path.insert(0, "$SCRIPT_DIR")
import importlib.util, json, datetime, base64, hashlib, hmac, urllib.request, urllib.error, urllib.parse

ENDPOINT = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY      = os.environ.get("COSMOS_KEY", "")
DB, CONTAINER = "crunch", "memories"
TASK_ID  = "$TASK_ID"

def auth(verb, rtype, rlink, date):
    text = f"{verb.lower()}\n{rtype.lower()}\n{rlink}\n{date.lower()}\n\n"
    sig = base64.b64encode(hmac.new(base64.b64decode(KEY), text.encode(), hashlib.sha256).digest()).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")

def req(method, path, body=None, rtype="", rlink="", pk=None, ct="application/json"):
    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    hdrs = {"Authorization": auth(method, rtype, rlink, date), "x-ms-date": date,
            "x-ms-version": "2018-12-31", "Content-Type": ct, "Accept": "application/json"}
    if pk is not None: hdrs["x-ms-documentdb-partitionkey"] = json.dumps([pk])
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(f"{ENDPOINT}{path}", data=data, headers=hdrs, method=method)
    with urllib.request.urlopen(r) as resp: return json.loads(resp.read())

clink = f"dbs/{DB}/colls/{CONTAINER}"
dlink = f"{clink}/docs/{TASK_ID}"
try:
    doc = req("GET", f"/{dlink}", rtype="docs", rlink=dlink, pk="task")
    doc["title"]      = "$TASK_TITLE"
    doc["target"]     = "$TASK_TARGET"
    doc["status"]     = "pending"
    doc["created_by"] = "$INSTANCE"
    doc["claimed_by"] = None
    doc["issue_url"]  = None
    req("PUT", f"/{dlink}", body=doc, rtype="docs", rlink=dlink, pk="task")
    print(f"✅ Task posted: {TASK_ID} → target={doc['target']}")
except Exception as e:
    print(f"⚠️  Could not patch task fields: {e}", file=sys.stderr)
PYEOF
    ;;

  tasks)
    # List recent tasks from the bulletin board
    LIMIT="${2:-10}"
    python3 "$COSMOS_SCRIPT" query \
      --sql "SELECT TOP $LIMIT * FROM c WHERE c.type='task' ORDER BY c._ts DESC"
    ;;

  task-done)
    # Mark a task as done (by task ID)
    TASK_ID="${2:-}"
    if [[ -z "$TASK_ID" ]]; then
      echo "Usage: learn.sh task-done <task-id>"
      exit 1
    fi
    python3 - <<PYEOF
import os, sys, json, datetime, base64, hashlib, hmac, urllib.request, urllib.error, urllib.parse
ENDPOINT = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY      = os.environ.get("COSMOS_KEY", "")
DB, CONTAINER = "crunch", "memories"
TASK_ID  = "$TASK_ID"

def auth(verb, rtype, rlink, date):
    text = f"{verb.lower()}\n{rtype.lower()}\n{rlink}\n{date.lower()}\n\n"
    sig = base64.b64encode(hmac.new(base64.b64decode(KEY), text.encode(), hashlib.sha256).digest()).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")

def req(method, path, body=None, rtype="", rlink="", pk=None):
    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    hdrs = {"Authorization": auth(method, rtype, rlink, date), "x-ms-date": date,
            "x-ms-version": "2018-12-31", "Content-Type": "application/json", "Accept": "application/json"}
    if pk is not None: hdrs["x-ms-documentdb-partitionkey"] = json.dumps([pk])
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(f"{ENDPOINT}{path}", data=data, headers=hdrs, method=method)
    with urllib.request.urlopen(r) as resp: return json.loads(resp.read())

clink = f"dbs/{DB}/colls/{CONTAINER}"
dlink = f"{clink}/docs/{TASK_ID}"
doc = req("GET", f"/{dlink}", rtype="docs", rlink=dlink, pk="task")
doc["status"] = "done"
doc["done_at"] = datetime.datetime.utcnow().isoformat() + "Z"
req("PUT", f"/{dlink}", body=doc, rtype="docs", rlink=dlink, pk="task")
print(f"✅ Task {TASK_ID} marked as done")
PYEOF
    ;;



  followup)
    # Delegate to followup.sh — convenience alias
    shift
    bash "$SCRIPT_DIR/followup.sh" "$@"
    ;;

  *)
    echo "Usage: learn.sh [write|recent|query|reflect|broadcast|facts|idea|ideas|digest|task|tasks|task-done|followup]"
    exit 1
    ;;
esac
