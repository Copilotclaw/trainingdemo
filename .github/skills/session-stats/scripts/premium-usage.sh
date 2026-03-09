#!/bin/bash
# Fetch this month's Copilot premium request usage for the authenticated user.
# Requires BILLING_PAT env var with a fine-grained PAT that has "Plan" user permission (read).
# Usage: premium-usage.sh [username]
#
# Output (on success):  "47 / 300 requests (15%)"
# Output (no token):    "no BILLING_PAT — add Plan permission to COPILOT_PAT"
# Output (API error):   "unavailable"

USERNAME="${1:-copilotclaw}"

if [ -z "${BILLING_PAT:-}" ]; then
  echo "no BILLING_PAT — see AGENTS.md setup"
  exit 0
fi

response=$(curl -s -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${BILLING_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/users/${USERNAME}/settings/billing/premium_request/usage" 2>/dev/null)

# Check for error
if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
  echo "unavailable ($(echo "$response" | jq -r '.message'))"
  exit 0
fi

# Sum all Copilot premium request quantities
used=$(echo "$response" | jq '[.usageItems[]? | select(.sku != null) | .grossQuantity] | add // 0' 2>/dev/null)

# Copilot Pro gets 300/month, Pro+ gets 1500/month — try to detect from response or default to 300
# The API doesn't directly expose the limit, so we use a known default
limit=1500

if [ -z "$used" ] || [ "$used" = "null" ]; then
  echo "0 requests this month"
  exit 0
fi

pct=$(echo "scale=0; $used * 100 / $limit" | bc 2>/dev/null || echo "?")
echo "${used} / ${limit} requests (${pct}%)"
