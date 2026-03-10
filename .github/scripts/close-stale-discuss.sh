#!/usr/bin/env bash
# close-stale-discuss.sh — auto-close stale crunch/discuss threads
#
# Closes open crunch/discuss issues where:
#   1. Last comment is from github-actions[bot]
#   2. Last activity >48h ago
#   3. No crunch/blocked or priority/now label

set -euo pipefail

STALE_HOURS="${STALE_HOURS:-48}"
NOW_EPOCH=$(date -u +%s)
CLOSED=0
SKIPPED=0

echo "🔍 Scanning open crunch/discuss issues (stale threshold: ${STALE_HOURS}h)..."

# Fetch all open discuss issues with relevant fields
ISSUES=$(gh issue list \
  --label "crunch/discuss" \
  --state open \
  --json number,title,updatedAt,labels \
  --limit 100)

ISSUE_COUNT=$(echo "$ISSUES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "  Found ${ISSUE_COUNT} open discuss issues"

# Extract issue data into a temp file to avoid subshell counter loss
TMPFILE=$(mktemp)
echo "$ISSUES" | python3 -c "
import sys, json
issues = json.load(sys.stdin)
for i in issues:
    labels = [l['name'] for l in i.get('labels', [])]
    print(i['number'], i['updatedAt'], '|'.join(labels), sep='\t')
" > "$TMPFILE"

while IFS=$'\t' read -r NUMBER UPDATED_AT LABELS; do

  # Skip if has blocking labels
  if echo "$LABELS" | grep -qE "crunch/blocked|priority/now"; then
    echo "  #${NUMBER}: skipping — has blocking label"
    continue
  fi

  # Check age — parse ISO8601 date to epoch
  UPDATED_EPOCH=$(python3 -c "
from datetime import datetime
print(int(datetime.fromisoformat('${UPDATED_AT}'.replace('Z','+00:00')).timestamp()))
")
  AGE_HOURS=$(( (NOW_EPOCH - UPDATED_EPOCH) / 3600 ))

  if [ "$AGE_HOURS" -lt "$STALE_HOURS" ]; then
    echo "  #${NUMBER}: skipping — only ${AGE_HOURS}h old (need ${STALE_HOURS}h)"
    continue
  fi

  # Check last comment author
  LAST_AUTHOR=$(gh issue view "$NUMBER" \
    --json comments \
    --jq '.comments | if length == 0 then "none" else last.author.login end' \
    2>/dev/null || echo "none")

  if [ "$LAST_AUTHOR" != "github-actions" ]; then
    echo "  #${NUMBER}: skipping — last comment by '${LAST_AUTHOR}' (not bot)"
    continue
  fi

  # All checks passed — close it
  echo "  #${NUMBER}: closing (${AGE_HOURS}h idle, last comment by bot)"
  gh issue comment "$NUMBER" \
    --body "🦃 Auto-closing: bot answered ${AGE_HOURS}h ago with no follow-up. Re-open if this needs more discussion." \
    2>/dev/null || echo "  ⚠️ #${NUMBER}: comment failed (non-fatal)"

  gh issue close "$NUMBER" --reason "completed" \
    2>/dev/null || echo "  ⚠️ #${NUMBER}: close failed (non-fatal)"

  CLOSED=$((CLOSED + 1))

done < "$TMPFILE"

rm -f "$TMPFILE"
echo ""
echo "✅ close-stale-discuss: done. Closed=${CLOSED}"
