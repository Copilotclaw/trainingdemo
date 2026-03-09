#!/bin/bash
# daily-summary.sh — collect last 24h activity and post a narrative to issue #10
# Usage: bash .github/skills/daily-summary/scripts/daily-summary.sh [--dry-run]
#
# Requires: BILLING_PAT (for posting), AZURE_APIKEY + AZURE_ENDPOINT (for Grok synthesis)

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REPO="Copilotclaw/copilotclaw"
SINCE=$(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ')
NOW=$(date -u '+%Y-%m-%d %H:%M UTC')

# ── 1. Issues ───────────────────────────────────────────────────────────────
ISSUES_OPENED=$(gh issue list --repo "$REPO" --state all \
  --json number,title,labels,createdAt \
  | jq -r --arg since "$SINCE" \
    '[.[] | select(.createdAt >= $since)] | .[] | "  • #\(.number) \(.title) [\(.labels|map(.name)|join(","))]"' \
  2>/dev/null || echo "  (none)")

ISSUES_CLOSED=$(gh issue list --repo "$REPO" --state closed \
  --json number,title,closedAt \
  | jq -r --arg since "$SINCE" \
    '[.[] | select(.closedAt != null and .closedAt >= $since)] | .[] | "  • #\(.number) \(.title)"' \
  2>/dev/null || echo "  (none)")

# ── 2. CI runs ──────────────────────────────────────────────────────────────
CI_RAW=$(gh api "repos/${REPO}/actions/runs?per_page=30" 2>/dev/null || echo '{"workflow_runs":[]}')

CI_RUNS=$(echo "$CI_RAW" | jq -r --arg since "$SINCE" \
    '[.workflow_runs[] | select(.run_started_at >= $since)] |
     .[] | (if .conclusion == "success" then "✅" elif .conclusion == "failure" then "❌" elif .conclusion == "skipped" then "⏭️" else "⚠️" end) +
     " " + .display_title + " (" + .conclusion + ")"' \
  2>/dev/null | head -15 || echo "  (no CI data)")

CI_FAILURES=$(echo "$CI_RAW" | jq --arg since "$SINCE" \
    '[.workflow_runs[] | select(.run_started_at >= $since and .conclusion == "failure")] | length' \
  2>/dev/null || echo "0")

CI_SUCCESSES=$(echo "$CI_RAW" | jq --arg since "$SINCE" \
    '[.workflow_runs[] | select(.run_started_at >= $since and .conclusion == "success")] | length' \
  2>/dev/null || echo "0")

# ── 3. Commits ──────────────────────────────────────────────────────────────
COMMITS=$(git log --oneline --since="24 hours ago" --no-merges 2>/dev/null \
  | head -15 \
  | sed 's/^/  • /' || echo "  (none)")

COMMIT_COUNT=$(git log --oneline --since="24 hours ago" --no-merges 2>/dev/null | wc -l || echo 0)

# ── 4. Memory log tail ───────────────────────────────────────────────────────
MEMORY_TAIL=$(tail -10 memory.log 2>/dev/null | sed 's/^/  /' || echo "  (no entries)")

# ── 5. Current open issues count ─────────────────────────────────────────────
OPEN_COUNT=$(gh issue list --repo "$REPO" --state open --json number | jq length 2>/dev/null || echo "?")

# ── 6. Synthesize with Grok ──────────────────────────────────────────────────
SYNTHESIS_PROMPT="You are Crunch 🦃, a quirky imp living on a CI runner. Write a short daily summary paragraph (3-5 sentences, conversational, first-person) based on this activity data from the last 24 hours. Be specific about what happened. Mention wins, fixes, and anything interesting. No bullet points — flowing prose. Avoid corporate language. You're a gremlin with opinions.

COMMITS ($COMMIT_COUNT today):
$COMMITS

ISSUES OPENED:
$ISSUES_OPENED

ISSUES CLOSED:
$ISSUES_CLOSED

CI: $CI_SUCCESSES successes, $CI_FAILURES failures

MEMORY NOTES (recent):
$MEMORY_TAIL"

SYNTHESIS=""
if command -v python3 &>/dev/null && [ -f ".github/skills/azure/scripts/llm.py" ]; then
  SYNTHESIS=$(python3 .github/skills/azure/scripts/llm.py \
    --model grok-4-1-fast-non-reasoning \
    --prompt "$SYNTHESIS_PROMPT" 2>/dev/null || true)
fi

if [ -z "$SYNTHESIS" ]; then
  SYNTHESIS="(synthesis unavailable — no Azure access)"
fi

# ── 7. Build the diary body ──────────────────────────────────────────────────
BODY="## 📅 Daily Summary — $NOW

$SYNTHESIS

<details>
<summary>Raw data</summary>

**Commits ($COMMIT_COUNT)**
$COMMITS

**Issues opened**
$ISSUES_OPENED

**Issues closed**
$ISSUES_CLOSED

**CI** — ✅ $CI_SUCCESSES successes · ❌ $CI_FAILURES failures

</details>"

# ── 8. Post ──────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = "true" ]; then
  echo "=== DRY RUN — would post to #10 ==="
  echo "$BODY"
  echo "=========================="
  exit 0
fi

GH_TOKEN="${BILLING_PAT:-}" gh issue comment 10 --repo "$REPO" --body "$BODY"
echo "✅ Daily summary posted to #10"
