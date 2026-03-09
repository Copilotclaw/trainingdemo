#!/usr/bin/env bash
# repo-allowlist.sh
# Validates that a target repo is on Crunch's allowed list before taking action.
#
# CRUNCH_REPOS env var: space or newline-separated list of allowed repos.
# Default (when unset): only Copilotclaw/copilotclaw is allowed.
#
# Usage:
#   repo-allowlist.sh check <repo>   → exits 0 (allowed) or 1 (blocked)
#   repo-allowlist.sh list           → prints the current allowlist
#
# Exit codes:
#   0  — repo is allowed, proceed
#   1  — repo is NOT on the list, abort

set -euo pipefail

DEFAULT_REPOS="Copilotclaw/copilotclaw Copilotclaw/private Copilotclaw/monitor Copilotclaw/braindumps Copilotclaw/brainstorm"
ALLOWED="${CRUNCH_REPOS:-$DEFAULT_REPOS}"
COMMAND="${1:-check}"
TARGET="${2:-}"

# Normalize to newline-separated list
ALLOWED_LIST=$(echo "$ALLOWED" | tr ' ,;' '\n' | grep -v '^$' | sort -u)

case "$COMMAND" in
  list)
    echo "repo-allowlist: allowed repos:"
    echo "$ALLOWED_LIST" | sed 's/^/  - /'
    ;;

  check)
    if [[ -z "$TARGET" ]]; then
      echo "repo-allowlist: no repo specified — defaulting to allowed"
      exit 0
    fi
    if echo "$ALLOWED_LIST" | grep -qxF "$TARGET"; then
      echo "repo-allowlist: ✅ $TARGET is allowed"
      exit 0
    else
      echo "repo-allowlist: ❌ $TARGET is NOT on the allowlist — blocked"
      echo "  Allowed: $(echo "$ALLOWED_LIST" | tr '\n' ' ')"
      echo "  To allow: set CRUNCH_REPOS env var or GitHub Actions secret"
      exit 1
    fi
    ;;

  *)
    echo "repo-allowlist: unknown command '$COMMAND'"
    exit 1
    ;;
esac
