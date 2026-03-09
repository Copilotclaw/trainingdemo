#!/bin/bash
# Fetch last N completed CI runs and print duration stats
# Usage: ci-stats.sh [count=5]
COUNT=${1:-5}
REPO="Copilotclaw/copilotclaw"

runs=$(gh api "repos/${REPO}/actions/runs?per_page=20" \
  --jq "[.workflow_runs[] | select(.status==\"completed\") | {
    conclusion: .conclusion,
    duration_s: ((.updated_at | fromdateiso8601) - (.run_started_at | fromdateiso8601)),
    started: .run_started_at
  }] | .[:${COUNT}]" 2>/dev/null)

if [ -z "$runs" ]; then
  echo "no CI data"
  exit 0
fi

echo "$runs" | jq -r '.[] |
  (if .conclusion == "success" then "✅" elif .conclusion == "failure" then "❌" else "⚠️" end) +
  " " + .started[:16] + "  " +
  (if .duration_s >= 60
    then ((.duration_s / 60 | floor | tostring) + "m " + (.duration_s % 60 | tostring) + "s")
    else (.duration_s | tostring) + "s"
   end)'
