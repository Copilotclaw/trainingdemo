#!/usr/bin/env bash
# autonomous-pickup.sh
# Scans for crunch/build issues labeled priority/now and posts a pickup comment
# using BILLING_PAT (authenticates as copilotclaw, not github-actions[bot]),
# which triggers agent.yml to work the issue.
#
# Platform-aware: works on GitHub Actions and Gitea Actions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/api.sh
source "$SCRIPT_DIR/lib/api.sh"

REPO="${GITHUB_REPOSITORY:-Copilotclaw/copilotclaw}"

if [[ -z "$API_TOKEN" ]]; then
  echo "autonomous-pickup: no auth token, skipping"
  exit 0
fi

# Find crunch/build + priority/now issues, not updated in the last 2 hours (to avoid thrashing)
THRESHOLD=$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
            date -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

if [[ -z "$THRESHOLD" ]]; then
  echo "autonomous-pickup: could not compute threshold date, skipping"
  exit 0
fi

# Check quota before doing anything (GitHub only — Gitea has no Copilot quota)
if [[ "$PLATFORM" != "gitea" ]]; then
  if ! bash "$SCRIPT_DIR/quota-guard.sh" check 2>/dev/null; then
    echo "autonomous-pickup: quota guard blocked — skipping pickup"
    exit 0
  fi
fi

# Fetch open issues with both labels
# GitHub API: comma = AND for labels. Gitea behaves the same.
CANDIDATES_JSON=$(api_get "repos/$REPO/issues?state=open&labels=crunch%2Fbuild,priority%2Fnow&per_page=5" || echo "[]")
CANDIDATES=$(echo "$CANDIDATES_JSON" | jq -r --arg threshold "$THRESHOLD" \
  '.[] | select((.updated_at // .updated // "9999") < $threshold) | "\(.number) \(.title)"' 2>/dev/null || echo "")

if [[ -z "$CANDIDATES" ]]; then
  echo "autonomous-pickup: no priority/now crunch/build issues ready for pickup"
  exit 0
fi

# Pick the first candidate
FIRST=$(echo "$CANDIDATES" | head -1)
NUM=$(echo "$FIRST" | cut -d' ' -f1)
TITLE=$(echo "$FIRST" | cut -d' ' -f2-)

echo "autonomous-pickup: posting pickup comment on #$NUM — $TITLE"

BODY="🤖 Heartbeat auto-pickup: working this issue now.

**Issue**: #${NUM} — ${TITLE}

Read the issue body and implement what's described. When done, label the issue \`crunch/review\` and summarize what you did.

<!-- crunch:posted -->"

api_post "repos/$REPO/issues/$NUM/comments" "$(jq -n --arg body "$BODY" '{body: $body}')"

echo "autonomous-pickup: comment posted on #$NUM — agent.yml should trigger shortly"
