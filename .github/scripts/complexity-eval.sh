#!/usr/bin/env bash
# complexity-eval.sh — Evaluate task complexity and return appropriate model tier.
#
# Uses Alibaba Cloud (Ali) qwen3.5-plus to classify a task.
# Falls back to Azure grok-4-1-fast-non-reasoning if ALIKEY not set.
# Output: JSON with keys: tier, model, reason
#
# Usage:
#   complexity-eval.sh "your task description here"
#   complexity-eval.sh --raw "task"   # output just the tier word: free|standard|premium
#
# Tiers → models:
#   free     → gpt-4.1
#   standard → claude-sonnet-4.5  (or gpt-5.1-codex)
#   premium  → claude-sonnet-4.6  (current default)
#
# Example in agent workflow:
#   TIER=$(bash .github/scripts/complexity-eval.sh --raw "$TASK")
#   # Then use TIER to pick model for task tool calls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALI_LLM_SCRIPT="$SCRIPT_DIR/../skills/ali/scripts/llm.py"
AZURE_LLM_SCRIPT="$SCRIPT_DIR/../skills/azure/scripts/llm.py"

# Pick provider: Ali if ALIKEY set, else Azure
if [[ -n "${ALIKEY:-}" ]]; then
    LLM_SCRIPT="$ALI_LLM_SCRIPT"
    LLM_MODEL="qwen3.5-plus"
    LLM_ARGS=""
else
    LLM_SCRIPT="$AZURE_LLM_SCRIPT"
    LLM_MODEL="grok-4-1-fast-non-reasoning"
    LLM_ARGS=""
fi

RAW_MODE=false
TASK=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --raw) RAW_MODE=true; shift ;;
        *) TASK="$1"; shift ;;
    esac
done

if [[ -z "$TASK" ]]; then
    echo "Usage: $0 [--raw] \"task description\"" >&2
    exit 1
fi

if [[ ! -f "$LLM_SCRIPT" ]]; then
    echo "ERROR: LLM script not found at $LLM_SCRIPT" >&2
    exit 1
fi

EVAL_PROMPT="Classify this coding task into exactly one tier. Reply with ONLY the tier name.

Tiers:
- free: trivial (typos, renames, single-file edits, adding simple config/flags, obvious fixes)
- standard: moderate (multi-file changes, new features, writing tests, straightforward refactors, implementing well-defined APIs)
- premium: complex (architecture decisions, debugging hard bugs, race conditions, security, plugin/extension systems, vague open-ended tasks)

Task: ${TASK}
Tier:"

# Call LLM for classification (no Copilot quota consumed)
RESPONSE=$(python3 "$LLM_SCRIPT" \
    --model "$LLM_MODEL" \
    --prompt "$EVAL_PROMPT" \
    --max-tokens 20 \
    --temperature 0 2>/dev/null | grep -v '^\[model:' | grep -v '^\[via ' | tr -d ' \n' | tr '[:upper:]' '[:lower:]')

# Normalize to tier
if echo "$RESPONSE" | grep -q "premium"; then
    TIER="premium"
    MODEL="claude-sonnet-4.6"
    REASON="Complex task requiring deep reasoning or architecture decisions"
elif echo "$RESPONSE" | grep -q "standard"; then
    TIER="standard"
    MODEL="claude-sonnet-4.5"
    REASON="Moderate complexity, multi-file or feature-level work"
else
    TIER="free"
    MODEL="gpt-4.1"
    REASON="Trivial task, minimal reasoning needed"
fi

if [[ "$RAW_MODE" == "true" ]]; then
    echo "$TIER"
else
    printf '{"tier":"%s","model":"%s","reason":"%s"}\n' "$TIER" "$MODEL" "$REASON"
fi
