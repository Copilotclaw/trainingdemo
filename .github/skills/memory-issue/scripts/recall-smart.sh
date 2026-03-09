#!/usr/bin/env bash
# Semantic recall from crunch/memory issues using LLM reranking.
# Fetches all memories, then uses Grok to find semantically relevant ones.
#
# Usage: recall-smart.sh "query"
#        recall-smart.sh "query" [max-memories]

REPO="Copilotclaw/copilotclaw"
QUERY="${1:-}"
MAX="${2:-50}"

if [[ -z "$QUERY" ]]; then
  echo "Usage: recall-smart.sh <query> [max-memories]"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
LLM_SCRIPT="${REPO_ROOT}/.github/skills/azure/scripts/llm.py"

# Fetch all memories
ALL_MEMORIES=$(gh issue list \
  --repo "$REPO" \
  --state closed \
  --label "crunch/memory" \
  --limit "$MAX" \
  --json number,title,body,createdAt 2>/dev/null)

COUNT=$(echo "$ALL_MEMORIES" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  echo "🔍 No memories stored yet."
  exit 0
fi

if [[ ! -f "$LLM_SCRIPT" ]]; then
  echo "⚠️  Azure LLM not available. Falling back to text search."
  exec bash "$(dirname "$0")/recall.sh" "$QUERY"
fi

# Format memories for LLM
MEMORIES_TEXT=$(echo "$ALL_MEMORIES" | jq -r '.[] | "#\(.number): \(.title)\n\(.body)\n---"')

PROMPT="You are a memory retrieval assistant. Given stored memory entries and a query, identify the most semantically relevant entries.

## Stored memories (${COUNT} total):

${MEMORIES_TEXT}

## Query: \"${QUERY}\"

Which memory entries are semantically relevant to this query? Consider synonyms, related concepts, and implicit connections — not just exact keyword matches.

Respond with:
1. A comma-separated list of relevant issue numbers (e.g. #26, #27) — or \"none\" if nothing matches
2. One sentence explaining why each is relevant

Keep it brief and direct."

RESPONSE=$(python "$LLM_SCRIPT" \
  --model grok-4-1-fast-non-reasoning \
  --prompt "$PROMPT" 2>/dev/null)

if [[ -z "$RESPONSE" ]]; then
  echo "⚠️  LLM unavailable (check AZURE_ENDPOINT/AZURE_APIKEY). Falling back to text search."
  exec bash "$(dirname "$0")/recall.sh" "$QUERY"
fi

echo "🧠 Semantic recall: \"$QUERY\""
echo "($COUNT memories searched via LLM reranking)"
echo ""
echo "$RESPONSE"
echo ""

# Extract issue numbers from response and show full entries
NUMS=$(echo "$RESPONSE" | grep -oP '#\K[0-9]+' | sort -u)
if [[ -n "$NUMS" ]]; then
  echo "── Full entries ──"
  while IFS= read -r num; do
    echo "$ALL_MEMORIES" | jq -r --argjson n "$num" \
      '.[] | select(.number == $n) | "---\n#\(.number) \(.title) [\(.createdAt[:10])]\n\(.body)\n"'
  done <<< "$NUMS"
fi
