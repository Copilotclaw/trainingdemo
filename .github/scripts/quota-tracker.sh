#!/bin/bash
# quota-tracker.sh — Track Copilot premium quota burn rate over time.
#
# Reads current quota, appends to state/quota-history.json,
# computes burn rate, and alerts Marcus on #11 if exhaustion projected within ALERT_DAYS.
#
# Usage: bash .github/scripts/quota-tracker.sh

set -euo pipefail

ALERT_DAYS="${ALERT_DAYS:-5}"
REPO="${GITHUB_REPOSITORY:-Copilotclaw/copilotclaw}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HISTORY_FILE="${REPO_ROOT}/state/quota-history.json"

# 1. Read current quota
if [ -z "${BILLING_PAT:-}" ]; then
  echo "quota-tracker: BILLING_PAT not set — skipping"
  exit 0
fi

USAGE_STR="$(bash "${SCRIPT_DIR}/../skills/session-stats/scripts/premium-usage.sh" copilotclaw 2>/dev/null || true)"

if [ -z "$USAGE_STR" ]; then
  echo "quota-tracker: no response from premium-usage.sh"
  exit 0
fi

if echo "$USAGE_STR" | grep -q "unavailable\|no BILLING_PAT\|no COPILOT_PAT"; then
  echo "quota-tracker: quota unavailable — ${USAGE_STR}"
  exit 0
fi

# Parse "350.0 / 1500 requests (23%)"
USED="$(echo "$USAGE_STR" | awk '{print $1}' | cut -d. -f1)"
LIMIT="$(echo "$USAGE_STR" | awk '{print $3}')"

if [ -z "$USED" ] || [ -z "$LIMIT" ]; then
  echo "quota-tracker: parse failed for: $USAGE_STR"
  exit 0
fi

echo "quota-tracker: current usage ${USED}/${LIMIT}"

NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
EPOCH="$(date -u '+%s')"

mkdir -p "${REPO_ROOT}/state"

# 2. Append data point
python3 "${SCRIPT_DIR}/quota-history-append.py" "$HISTORY_FILE" "$NOW" "$EPOCH" "$USED" "$LIMIT"

# 3. Compute burn rate and alert
python3 "${SCRIPT_DIR}/quota-tracker-compute.py" "$HISTORY_FILE" "$ALERT_DAYS" "$REPO"

echo "quota-tracker: done"
