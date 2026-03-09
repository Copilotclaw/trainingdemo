#!/usr/bin/env bash
# sub-repo-scan.sh
# Scans sub-repos for open issues and escalates them to copilotclaw.
#
# For each sub-repo type:
#   monitor       → unresolved alert issues → create priority/now in copilotclaw
#   braindumps    → open task issues        → create crunch/build priority/now in copilotclaw
#   brainstorm    → priority ideas stale 7d → comment on copilotclaw #11 (Marcus ping)
#
# Sub-repos are GitHub repos — always uses GitHub API directly with BILLING_PAT.
# On Gitea: uses BILLING_PAT for GitHub API calls (cross-platform fetch).

set -euo pipefail

TOKEN="${BILLING_PAT:-${COPILOT_GITHUB_TOKEN:-}}"
if [[ -z "$TOKEN" ]]; then
  echo "sub-repo-scan: no auth token, skipping"
  exit 0
fi

# Sub-repos live on GitHub — always use GitHub API
GH_API="https://api.github.com"

gh_api_get() {
  curl -sf -X GET \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/json" \
    "$GH_API/$1"
}

gh_api_post() {
  curl -sf -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$GH_API/$1" -d "$2"
}

MAIN_REPO="Copilotclaw/copilotclaw"

# ──────────────────────────────────────────────
# 1. monitor — escalate unresolved alert issues
# ──────────────────────────────────────────────
echo "sub-repo-scan: checking Copilotclaw/monitor..."
MONITOR_ISSUES=$(gh_api_get "repos/Copilotclaw/monitor/issues?state=open&per_page=10" 2>/dev/null || echo "[]")

echo "$MONITOR_ISSUES" | jq -c '.[]' 2>/dev/null | while read -r issue; do
  NUM=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title')
  CREATED=$(echo "$issue" | jq -r '.created_at')
  BODY=$(echo "$issue" | jq -r '.body // ""' | head -c 1000)

  # Check if we already escalated this — use search API to avoid per_page=100 blind spot
  SEARCH_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('repo:Copilotclaw/copilotclaw monitor#${NUM} in:title,body'))")
  ALREADY=$(curl -sf -X GET \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/json" \
    "${GH_API}/search/issues?q=${SEARCH_QUERY}&per_page=1" \
    | jq -r '.items[0].number // empty' 2>/dev/null || echo "")

  if [[ -n "$ALREADY" ]]; then
    echo "sub-repo-scan: monitor#${NUM} already escalated to copilotclaw#${ALREADY}, skipping"
    continue
  fi

  echo "sub-repo-scan: escalating monitor#${NUM}: ${TITLE}"
  ISSUE_BODY=$(printf 'Escalated from [Copilotclaw/monitor#%s](https://github.com/Copilotclaw/monitor/issues/%s) (opened %s).\n\n---\n\n%s\n\n<!-- crunch-depth: 1 -->' \
    "$NUM" "$NUM" "$CREATED" "$BODY")
  gh_api_post "repos/$MAIN_REPO/issues" \
    "$(jq -n --arg t "🚨 [monitor] ${TITLE}" --arg b "$ISSUE_BODY" \
       '{title: $t, body: $b, labels: ["crunch/build","priority/now","bug"]}')" \
    2>/dev/null || true

  gh_api_post "repos/Copilotclaw/monitor/issues/$NUM/comments" \
    '{"body":"🦃 Picked up by Crunch heartbeat — escalated to copilotclaw for handling."}' \
    2>/dev/null || true
done

# ──────────────────────────────────────────────
# 2. braindumps — create pickup tasks
# ──────────────────────────────────────────────
echo "sub-repo-scan: checking Copilotclaw/braindumps..."
BRAINDUMP_ISSUES=$(gh_api_get "repos/Copilotclaw/braindumps/issues?state=open&per_page=10" 2>/dev/null || echo "[]")

echo "$BRAINDUMP_ISSUES" | jq -c '.[]' 2>/dev/null | while read -r issue; do
  NUM=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title')
  CREATED=$(echo "$issue" | jq -r '.created_at')
  BODY=$(echo "$issue" | jq -r '.body // ""' | head -c 1000)

  # Check if already escalated — use search API to avoid per_page=100 blind spot
  SEARCH_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('repo:Copilotclaw/copilotclaw braindumps#${NUM} in:title,body'))")
  ALREADY=$(curl -sf -X GET \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/json" \
    "${GH_API}/search/issues?q=${SEARCH_QUERY}&per_page=1" \
    | jq -r '.items[0].number // empty' 2>/dev/null || echo "")

  if [[ -n "$ALREADY" ]]; then
    echo "sub-repo-scan: braindumps#${NUM} already escalated to copilotclaw#${ALREADY}, skipping"
    continue
  fi

  echo "sub-repo-scan: escalating braindumps#${NUM}: ${TITLE}"
  ISSUE_BODY=$(printf 'Task from [Copilotclaw/braindumps#%s](https://github.com/Copilotclaw/braindumps/issues/%s) (opened %s).\n\n---\n\n%s\n\n<!-- crunch-depth: 1 -->' \
    "$NUM" "$NUM" "$CREATED" "$BODY")
  gh_api_post "repos/$MAIN_REPO/issues" \
    "$(jq -n --arg t "🧠 [braindumps#${NUM}] ${TITLE}" --arg b "$ISSUE_BODY" \
       '{title: $t, body: $b, labels: ["crunch/build","priority/now"]}')" \
    2>/dev/null || true

  gh_api_post "repos/Copilotclaw/braindumps/issues/$NUM/comments" \
    '{"body":"🦃 Picked up by Crunch heartbeat — task queued in copilotclaw."}' \
    2>/dev/null || true
done

# ──────────────────────────────────────────────
# 3. brainstorm — ping Marcus on stale priority ideas
# ──────────────────────────────────────────────
echo "sub-repo-scan: checking Copilotclaw/brainstorm priority ideas..."
STALE_THRESHOLD=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                  date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

if [[ -n "$STALE_THRESHOLD" ]]; then
  STALE_IDEAS=$(gh_api_get "repos/Copilotclaw/brainstorm/issues?state=open&labels=priority&per_page=10" 2>/dev/null \
    | jq -r --arg t "$STALE_THRESHOLD" \
      '.[] | select((.updated_at // .updated // "9999") < $t) | "#\(.number) \(.title)"' 2>/dev/null || echo "")

  if [[ -n "$STALE_IDEAS" ]]; then
    COUNT=$(echo "$STALE_IDEAS" | wc -l | tr -d ' ')
    echo "sub-repo-scan: ${COUNT} stale priority ideas in brainstorm"
    PING_BODY=$(printf '👋 Marcus — %s priority idea(s) in brainstorm have been sitting for 7+ days:\n\n%s\n\nWant me to promote any to a crunch/build task?' "$COUNT" "$STALE_IDEAS")
    # Use GH_BOT_TOKEN if available so this ping doesn't re-trigger agent.yml
    BOT_TOKEN="${GH_BOT_TOKEN:-$TOKEN}"
    curl -sf -X POST \
      -H "Authorization: token $BOT_TOKEN" \
      -H "Content-Type: application/json" \
      "$GH_API/repos/$MAIN_REPO/issues/11/comments" \
      -d "$(jq -n --arg body "$PING_BODY" '{body: $body}')" \
      2>/dev/null || true
  fi
fi

echo "sub-repo-scan: done"
