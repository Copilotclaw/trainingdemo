#!/usr/bin/env bash
# shell-safe-check.sh — scan repo shell scripts for patterns blocked by the Copilot CLI security filter.
# Exits 0 if clean, 1 if violations found.
# Usage: bash .github/scripts/shell-safe-check.sh [path]
#   path defaults to repo root (current directory)

set -euo pipefail

SCAN_ROOT="${1:-.}"
VIOLATIONS=0

# Patterns that get blocked by the security filter
# Each entry: "pattern" "description"
BLOCKED_PATTERNS=(
  '\$\{[a-zA-Z_][a-zA-Z0-9_]*@[PULQuE]\}'
  '\$\{![a-zA-Z_][a-zA-Z0-9_]*\}'
  '\$\{![a-zA-Z_][a-zA-Z0-9_]*\[@\]\}'
)

BLOCKED_DESCRIPTIONS=(
  'Parameter transformation (${var@P/U/L/Q/u/E}) — use tr/printf/%q instead'
  'Indirect expansion (${!var}) — use python3 os.environ.get() instead'
  'Indirect array keys (${!arr[@]}) — use python3 for key iteration instead'
)

SELF="$(realpath "${BASH_SOURCE[0]}")"

# Helper: filter out non-violations (comments, escaped dollars, lines with # nocheck)
_filter_real() {
  grep -v '^\s*#' \
  | grep -v '\\${'  \
  | grep -v '#\s*nocheck'
}

find "$SCAN_ROOT" -type f \( -name "*.sh" -o -name "*.bash" \) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  | sort \
  | while IFS= read -r file; do
    real_file="$(realpath "$file")"
    # Skip self — this script documents the patterns it checks for
    [ "$real_file" = "$SELF" ] && continue
    for i in 0 1 2; do
      pattern="${BLOCKED_PATTERNS[$i]}"
      desc="${BLOCKED_DESCRIPTIONS[$i]}"
      matches=$(grep -nE "$pattern" "$file" 2>/dev/null | _filter_real || true)
      if [ -n "$matches" ]; then
        echo "VIOLATION: $file"
        echo "  Rule: $desc"
        echo "$matches" | while IFS= read -r line; do
          echo "  $line"
        done
        echo ""
      fi
    done
  done

# Re-run to get exit code (subshell above can't set outer VIOLATIONS)
found=0
for file in $(find "$SCAN_ROOT" -type f \( -name "*.sh" -o -name "*.bash" \) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" | sort); do
  real_file="$(realpath "$file")"
  [ "$real_file" = "$SELF" ] && continue
  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if grep -E "$pattern" "$file" 2>/dev/null | _filter_real | grep -q .; then
      found=1
      break
    fi
  done
done

if [ "$found" -eq 0 ]; then
  echo "✅ shell-safe-check: no blocked patterns found in $SCAN_ROOT"
  exit 0
else
  echo "❌ shell-safe-check: blocked patterns found — see above. Docs: docs/shell-safety.md"
  exit 1
fi
