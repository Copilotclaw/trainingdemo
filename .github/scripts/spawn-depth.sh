#!/usr/bin/env bash
# spawn-depth.sh
# Reads or enforces the spawn depth for an issue.
# Every issue Crunch creates for autonomous work should include
# a metadata marker:  <!-- crunch-depth: N -->
#
# Usage:
#   spawn-depth.sh read <issue_number>    → prints depth integer
#   spawn-depth.sh check <issue_number>   → exits 0 (ok) or 1 (max depth hit)
#   spawn-depth.sh tag <N>                → prints the metadata marker to embed in an issue body
#
# Max depth: 3 (configurable via CRUNCH_MAX_DEPTH env var)

set -euo pipefail

REPO="${CRUNCH_REPO:-Copilotclaw/copilotclaw}"
MAX_DEPTH="${CRUNCH_MAX_DEPTH:-3}"
COMMAND="${1:-}"
ARG="${2:-}"

if [[ -z "$COMMAND" ]]; then
  echo "Usage: spawn-depth.sh <read|check|tag> [issue_number|depth]"
  exit 1
fi

case "$COMMAND" in
  tag)
    DEPTH="${ARG:-1}"
    echo "<!-- crunch-depth: $DEPTH -->"
    ;;

  read)
    if [[ -z "$ARG" ]]; then
      echo "0"
      exit 0
    fi
    # Platform-aware: use GitHub API or Gitea API depending on environment
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    # shellcheck source=lib/api.sh
    source "$SCRIPT_DIR/lib/api.sh"
    BODY=$(api_get "repos/$REPO/issues/$ARG" 2>/dev/null | jq -r '.body // ""' || echo "")
    DEPTH=$(echo "$BODY" | grep -oP '<!-- crunch-depth: \K[0-9]+' | head -1 || echo "0")
    echo "${DEPTH:-0}"
    ;;

  check)
    if [[ -z "$ARG" ]]; then
      echo "spawn-depth: no issue number given, allowing (depth 0)"
      exit 0
    fi
    CURRENT=$(bash "$(dirname "$0")/spawn-depth.sh" read "$ARG")
    if [[ "$CURRENT" -ge "$MAX_DEPTH" ]]; then
      echo "spawn-depth: BLOCKED — issue #$ARG is at depth $CURRENT (max $MAX_DEPTH)"
      exit 1
    else
      echo "spawn-depth: OK — issue #$ARG is at depth $CURRENT (max $MAX_DEPTH)"
      exit 0
    fi
    ;;

  *)
    echo "spawn-depth: unknown command '$COMMAND'"
    exit 1
    ;;
esac
