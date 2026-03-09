#!/usr/bin/env bash
# test-alikey.sh — Validates that ALIKEY is set and can reach DashScope API.
# Usage: bash .github/scripts/test-alikey.sh
# Exit codes: 0=success, 1=missing key, 2=auth failure, 3=other error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLM_SCRIPT="$SCRIPT_DIR/../skills/ali/scripts/llm.py"

echo "=== ALIKEY validation test ==="

# 1. Check key is set
if [ -z "${ALIKEY:-}" ]; then
  echo "::error::ALIKEY is not set or empty."
  exit 1
fi

KEY_PREFIX="${ALIKEY:0:8}"
echo "✓ ALIKEY is set (prefix: ${KEY_PREFIX}...)"

# 2. Check llm.py is available
if [ ! -f "$LLM_SCRIPT" ]; then
  echo "::error::ALI llm.py not found at $LLM_SCRIPT"
  exit 3
fi

# 3. Ensure openai package
echo "Checking openai package..."
if ! python3 -c "import openai" 2>/dev/null; then
  echo "Installing openai..."
  pip install openai -q
fi

# 4. Run a minimal test call — capture stdout and stderr separately
echo "Calling DashScope API (qwen3-coder-plus, minimal prompt)..."
STDERR_LOG=$(mktemp)
STDOUT=$(python3 "$LLM_SCRIPT" \
  --model qwen3-coder-plus \
  --max-tokens 10 \
  --prompt "Reply with: ok" 2>"$STDERR_LOG") || CALL_EXIT=$?

CALL_EXIT="${CALL_EXIT:-0}"
STDERR_CONTENT=$(cat "$STDERR_LOG")
rm -f "$STDERR_LOG"

if [ -n "$STDERR_CONTENT" ]; then
  echo "--- stderr output ---"
  echo "$STDERR_CONTENT"
  echo "---------------------"
fi

if [ "$CALL_EXIT" -ne 0 ]; then
  # Check for auth-related error
  if echo "$STDERR_CONTENT" | grep -qi "401\|unauthorized\|invalid.*key\|authentication"; then
    echo "::error::ALIKEY authentication failed (401). The key is expired or invalid."
    exit 2
  fi
  echo "::error::ALI API call failed (exit $CALL_EXIT). See stderr above."
  exit 3
fi

echo "✓ API call succeeded"
echo "Response: $STDOUT"
echo "=== ALIKEY is valid and working ==="
exit 0
