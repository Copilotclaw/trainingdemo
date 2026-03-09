#!/usr/bin/env bash
# Store a fact as a closed GitHub issue in the crunch/memory archive.
# Usage: store.sh "Title" "Body" [category-label]
set -e

REPO="Copilotclaw/copilotclaw"
TITLE="${1:?Usage: store.sh <title> <body> [category-label]}"
BODY="${2:?Body required}"
CATEGORY="${3:-}"

# Ensure base label exists
gh label create "crunch/memory" --color "0075ca" --description "Episodic memory archive" --repo "$REPO" 2>/dev/null || true

LABELS="crunch/memory"

if [[ -n "$CATEGORY" ]]; then
  # Ensure category label exists
  gh label create "$CATEGORY" --color "e4e669" --description "Memory category: $CATEGORY" --repo "$REPO" 2>/dev/null || true
  LABELS="crunch/memory,$CATEGORY"
fi

URL=$(gh issue create \
  --repo "$REPO" \
  --title "$TITLE" \
  --body "$BODY" \
  --label "$LABELS")

# Extract issue number and close it
NUMBER=$(echo "$URL" | grep -oP 'issues/\K[0-9]+')
gh issue close "$NUMBER" --repo "$REPO" --comment "Memory archived." 2>/dev/null || true

echo "✅ Memory stored: $URL"
