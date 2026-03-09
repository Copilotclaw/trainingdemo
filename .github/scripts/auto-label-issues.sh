#!/usr/bin/env bash
# Auto-label unlabeled open issues using Grok classification.
# Called from heartbeat. Skips structural issues #10 #11.
#
# Requires: AZURE_ENDPOINT, AZURE_APIKEY
# Platform-aware: works on GitHub Actions and Gitea Actions.
# Usage: bash .github/scripts/auto-label-issues.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/api.sh
source "$SCRIPT_DIR/lib/api.sh"

# Pick LLM provider: Ali if ALIKEY set, else Azure
if [[ -n "${ALIKEY:-}" ]]; then
  LLM_SCRIPT="$SCRIPT_DIR/../skills/ali/scripts/llm.py"
  LLM_MODEL="qwen3-coder-plus"
else
  LLM_SCRIPT="$SCRIPT_DIR/../skills/azure/scripts/llm.py"
  LLM_MODEL="grok-4-1-fast-non-reasoning"
fi

REPO="${GITHUB_REPOSITORY:-Copilotclaw/copilotclaw}"
SKIP_ISSUES="10 11"

echo "🏷️  Auto-labeling unlabeled issues..."

# Get unlabeled open issues via platform API
ISSUES_JSON=$(api_get "repos/$REPO/issues?state=open&type=issues&per_page=50" || echo "[]")
UNLABELED=$(echo "$ISSUES_JSON" | jq -r \
  '.[] | select((.labels | length == 0) and (.pull_request == null)) | "\(.number)\t\(.title)\t\(.body // "" | gsub("\n";" ") | .[0:300])"' \
  2>/dev/null || echo "")

if [[ -z "$UNLABELED" ]]; then
  echo "No unlabeled issues found."
  exit 0
fi

LABELED_COUNT=0

while IFS=$'\t' read -r num title body; do
  # Skip structural issues
  if echo "$SKIP_ISSUES" | grep -qw "$num"; then
    continue
  fi

  echo "  → Issue #$num: $title"

  # Classify with Grok
  # Use printf %s to embed untrusted content safely — prevents backtick/$(...)
  # execution that would otherwise occur inside a double-quoted PROMPT= string.
  PROMPT=$(printf 'Classify this GitHub issue into exactly ONE label from this list:\ncrunch/build (implementing/creating/fixing/building something)\ncrunch/proposal (idea/suggestion/proposal for a new feature or change)\ncrunch/research (exploring/researching/reading/understanding something)\ncrunch/watch (monitoring/tracking something over time)\ncrunch/discuss (conversational, vague, unclear, or meta discussion)\n\nIssue title: %s\nIssue body: %s\n\nReply with ONLY the label name, nothing else.' "$title" "$body")

  LABEL=$(python3 "$LLM_SCRIPT" \
    --model "$LLM_MODEL" \
    --prompt "$PROMPT" \
    --max-tokens 20 2>/dev/null || echo "crunch/discuss")
  LABEL=$(echo "$LABEL" | tr -d '[:space:]' | head -c 40)

  # Validate label is one of the allowed set
  case "$LABEL" in
    crunch/build|crunch/proposal|crunch/research|crunch/watch|crunch/discuss)
      ;;
    *)
      echo "    ⚠️  Unexpected label '$LABEL' — falling back to crunch/discuss"
      LABEL="crunch/discuss"
      ;;
  esac

  # Apply label (ensure it exists first, then add to issue)
  if [[ "$LABEL" == "crunch/discuss" ]]; then
    # Ensure label exists — create if missing
    api_post "repos/$REPO/labels" \
      '{"name":"crunch/discuss","color":"d93f0b","description":"Conversational or meta discussion"}' \
      2>/dev/null || true
  fi

  # Add label via platform-aware helper
  GITHUB_REPOSITORY="$REPO" python3 "$SCRIPT_DIR/lib/issue_add_label.py" "$num" "$LABEL" 2>/dev/null && {
    echo "    ✅ Labeled #$num as $LABEL"
    LABELED_COUNT=$((LABELED_COUNT + 1))
  } || echo "    ❌ Failed to label #$num"

done <<< "$UNLABELED"

echo "🏷️  Done. Labeled $LABELED_COUNT issue(s)."
