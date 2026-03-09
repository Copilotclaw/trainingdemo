#!/usr/bin/env bash
# Recall memories from closed crunch/memory issues.
# Usage: recall.sh "query" [category-label]
#        recall.sh ""         → list all memories

REPO="Copilotclaw/copilotclaw"
QUERY="${1:-}"
CATEGORY="${2:-}"

LABEL_FILTER="crunch/memory"
if [[ -n "$CATEGORY" ]]; then
  LABEL_FILTER="$LABEL_FILTER,$CATEGORY"
fi

if [[ -n "$QUERY" ]]; then
  RESULTS=$(gh issue list \
    --repo "$REPO" \
    --state closed \
    --label "$LABEL_FILTER" \
    --search "$QUERY" \
    --limit 10 \
    --json number,title,body,url,createdAt 2>/dev/null)
else
  RESULTS=$(gh issue list \
    --repo "$REPO" \
    --state closed \
    --label "$LABEL_FILTER" \
    --limit 20 \
    --json number,title,body,url,createdAt 2>/dev/null)
fi

COUNT=$(echo "$RESULTS" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  echo "🔍 No memories found for: '${QUERY}'"
  exit 0
fi

echo "🧠 Found $COUNT memor$([ "$COUNT" -eq 1 ] && echo y || echo ies):"
echo ""

echo "$RESULTS" | jq -r '.[] | "---\n#\(.number) \(.title)\n\(.url)\n\n\(.body)\n"'
