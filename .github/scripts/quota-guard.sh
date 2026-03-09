#!/usr/bin/env bash
# quota-guard.sh
# Reads Copilot premium usage and blocks autonomous work if usage >= threshold.
# Pings Marcus on issue #11 if quota is critically high.
#
# Usage:
#   quota-guard.sh [check]            → exits 0 (ok to proceed) or 1 (quota high, abort)
#   quota-guard.sh status             → prints usage without blocking
#
# Configuration:
#   BILLING_PAT      — PAT with "Plan" user permission (read)
#   CRUNCH_QUOTA_WARN  — warn threshold, default 80 (%)
#   CRUNCH_QUOTA_BLOCK — block threshold, default 90 (%)
#   CRUNCH_REPO      — repo for pinging Marcus, default Copilotclaw/copilotclaw

set -euo pipefail

COMMAND="${1:-check}"
REPO="${CRUNCH_REPO:-Copilotclaw/copilotclaw}"
WARN_PCT="${CRUNCH_QUOTA_WARN:-80}"
BLOCK_PCT="${CRUNCH_QUOTA_BLOCK:-90}"

SKILLS_DIR="$(dirname "$0")/../../.github/skills/session-stats/scripts"
USAGE_SCRIPT="$SKILLS_DIR/premium-usage.sh"

# Fetch usage
if [[ ! -f "$USAGE_SCRIPT" ]]; then
  echo "quota-guard: usage script not found at $USAGE_SCRIPT — skipping check"
  exit 0
fi

RAW=$(bash "$USAGE_SCRIPT" copilotclaw 2>/dev/null || echo "unavailable")

# Parse "used / limit (pct%)" format
USED=$(echo "$RAW" | grep -oP '^\d+' || echo "")
LIMIT=$(echo "$RAW" | grep -oP '/ \K\d+' || echo "")
PCT=$(echo "$RAW" | grep -oP '\(\K\d+' || echo "")

if [[ -z "$PCT" ]]; then
  echo "quota-guard: usage unavailable ('$RAW') — allowing autonomous work to proceed"
  exit 0
fi

echo "quota-guard: Copilot usage ${USED}/${LIMIT} (${PCT}%)"

if [[ "$COMMAND" == "status" ]]; then
  exit 0
fi

# Block check
if [[ "$PCT" -ge "$BLOCK_PCT" ]]; then
  echo "quota-guard: 🚨 BLOCKED — usage ${PCT}% >= block threshold ${BLOCK_PCT}%"
  # Ping Marcus if BILLING_PAT available (always GitHub API — quota is GitHub-side)
  if [[ -n "${BILLING_PAT:-}" ]]; then
    BODY="⚠️ **Quota guard triggered** — Copilot usage at **${PCT}%** (${USED}/${LIMIT}). Autonomous work paused until usage drops below ${BLOCK_PCT}%."
    curl -sf -X POST \
      -H "Authorization: token $BILLING_PAT" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$REPO/issues/11/comments" \
      -d "$(jq -n --arg body "$BODY" '{body: $body}')" 2>/dev/null || true
  fi
  exit 1
fi

if [[ "$PCT" -ge "$WARN_PCT" ]]; then
  echo "quota-guard: ⚠️  WARNING — usage ${PCT}% >= warn threshold ${WARN_PCT}% — proceeding but be conservative"
  exit 0
fi

echo "quota-guard: ✅ usage ${PCT}% — proceed"
exit 0
