#!/usr/bin/env bash
# cosmos-session-state.sh — Write a structured session_state document to Cosmos DB
# Called by heartbeat to give Spark real-time context on Crunch's state
# Reads from environment: COSMOS_ENDPOINT, COSMOS_KEY

set -euo pipefail

if [ -z "${COSMOS_ENDPOINT:-}" ] || [ -z "${COSMOS_KEY:-}" ]; then
  echo "⚠️ COSMOS_ENDPOINT/COSMOS_KEY not set — skipping session state write"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/api.sh
source "$SCRIPT_DIR/lib/api.sh"

REPO="${GITHUB_REPOSITORY:-Copilotclaw/copilotclaw}"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Gather open issues count via platform-aware API
OPEN_ISSUES=$(api_get "repos/$REPO/issues?state=open&type=issues&per_page=1" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else '?')" || echo "unknown")
PRIORITY_NOW=$(api_get "repos/$REPO/issues?state=open&labels=priority%2Fnow&type=issues&per_page=50" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else '0')" || echo "0")
PROPOSALS=$(api_get "repos/$REPO/issues?state=open&labels=crunch%2Fproposal&type=issues&per_page=50" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else '?')" || echo "unknown")

CONTENT="Crunch heartbeat state @ ${TIMESTAMP}

Status: alive
Open issues: ${OPEN_ISSUES} (priority/now: ${PRIORITY_NOW}, proposals: ${PROPOSALS})
Last heartbeat: ${TIMESTAMP}
Repo: https://github.com/Copilotclaw/copilotclaw
Inbox: Issue #104 (spark/claimed — Spark can post spark/ping to wake me)

Active proposals:
- #96 Cosmos shared brain (priority/soon)
- #95 Spark task fallback (priority/soon)
- #93 Azure Queue bridge (priority/soon)
- #82 Migrate scripts to platform.py (priority/soon)

Recent activity: Spark comms channel live (#104), spark-inbox-scan wired into heartbeat, Cosmos diary persisting every beat."

python3 .github/scripts/cosmos-memory.py write \
  --type session_state \
  --content "$CONTENT" \
  --tags "heartbeat,crunch,state" \
  --source heartbeat \
  && echo "✅ Session state saved to Cosmos DB" || echo "⚠️ Cosmos session state write failed (non-fatal)"
