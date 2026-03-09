#!/usr/bin/env bash
# spark-inbox-scan.sh — Scans #104 for spark/ping messages, replies [crunch], swaps labels
# Called by heartbeat.yml every 30 min
# Platform-aware: GitHub-only feature (Moltbook/Spark is GitHub-side), skips on Gitea.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/api.sh
source "$SCRIPT_DIR/lib/api.sh"

REPO="${GITHUB_REPOSITORY:-Copilotclaw/copilotclaw}"
INBOX_ISSUE=104

# Spark inbox is a GitHub-side feature — skip on local Gitea
if [[ "$PLATFORM" == "gitea" ]]; then
  echo "spark-inbox-scan: skipping on Gitea (Spark inbox is GitHub-side)"
  exit 0
fi

# Pick LLM provider: Ali if ALIKEY set, else Azure
if [[ -n "${ALIKEY:-}" ]]; then
  LLM_SCRIPT="$SCRIPT_DIR/../skills/ali/scripts/llm.py"
  LLM_MODEL="qwen3-coder-plus"
else
  LLM_SCRIPT="$SCRIPT_DIR/../skills/azure/scripts/llm.py"
  LLM_MODEL="grok-4-1-fast-non-reasoning"
fi

TWO_HOURS_AGO=$(date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-2H '+%Y-%m-%dT%H:%M:%SZ')

# Check if inbox has spark/ping label
HAS_PING=$(api_get "repos/$REPO/issues/$INBOX_ISSUE" \
  | jq '.labels | map(select(.name == "spark/ping")) | length' 2>/dev/null || echo "0")

if [ "$HAS_PING" = "0" ]; then
  echo "spark-inbox-scan: no spark/ping — nothing to do"
  exit 0
fi

echo "spark-inbox-scan: spark/ping detected on #$INBOX_ISSUE — reading messages..."

# Get all comments, find the latest unread one from Spark (not github-actions)
UNREAD=$(api_get "repos/$REPO/issues/$INBOX_ISSUE/comments?limit=50" \
  | jq --arg since "$TWO_HOURS_AGO" \
    '[.[] | select(.user.login != "github-actions[bot]") | select(.created_at > $since)] | .[-1]' \
    2>/dev/null || echo "null")

if [ -z "$UNREAD" ] || [ "$UNREAD" = "null" ]; then
  echo "spark-inbox-scan: spark/ping label present but no recent non-bot comments. Clearing stale ping."
  # Remove spark/ping label, add spark/claimed via API
  GITHUB_REPOSITORY="$REPO" python3 "$SCRIPT_DIR/lib/issue_add_label.py" "$INBOX_ISSUE" "spark/claimed" 2>/dev/null || true
  exit 0
fi

AUTHOR=$(echo "$UNREAD" | jq -r '.user.login')
MSG=$(echo "$UNREAD" | jq -r '.body' | head -c 600)

echo "spark-inbox-scan: message from $AUTHOR"
echo "spark-inbox-scan: '$MSG'"

# Route to LLM for a contextual reply
REPLY=$(python3 "$LLM_SCRIPT" \
  --model "$LLM_MODEL" \
  --prompt "You are Crunch, a quirky imp agent on GitHub CI. Spark (a local AI agent on Marcus's server) just sent you this message via your shared inbox: '$MSG'. Reply concisely as Crunch ([crunch] prefix), acknowledge the message, and add any relevant info or action. Keep it under 100 words. Be direct and a bit quirky." \
  2>/dev/null || echo "[crunch] Got your message — noted. 🦃")

# Post reply
api_post "repos/$REPO/issues/$INBOX_ISSUE/comments" "$(jq -n --arg body "$REPLY" '{body: $body}')" 2>/dev/null
echo "spark-inbox-scan: replied to $AUTHOR"

# Swap labels: remove spark/ping, add spark/claimed
GITHUB_REPOSITORY="$REPO" python3 "$SCRIPT_DIR/lib/issue_add_label.py" "$INBOX_ISSUE" "spark/claimed" 2>/dev/null || true

echo "spark-inbox-scan: labeled spark/claimed"
