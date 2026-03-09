#!/bin/bash
# Read Azure call usage log and output compact stats.
# Usage: azure-stats.sh [log_file]
# Log file defaults to $AZURE_CALL_LOG or /tmp/crunch_azure_calls.jsonl

LOG="${1:-${AZURE_CALL_LOG:-/tmp/crunch_azure_calls.jsonl}}"

if [ ! -f "$LOG" ] || [ ! -s "$LOG" ]; then
  echo "0 calls"
  exit 0
fi

# Sum calls and tokens by model
python3 - "$LOG" <<'PYEOF'
import sys, json, collections

log_file = sys.argv[1]
models = collections.defaultdict(lambda: {"calls": 0, "tokens": 0})

with open(log_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            m = entry.get("model", "unknown")
            models[m]["calls"] += 1
            models[m]["tokens"] += entry.get("total_tokens", 0)
        except Exception:
            pass

if not models:
    print("0 calls")
else:
    parts = []
    for model, stats in sorted(models.items()):
        short = model.replace("grok-4-1-fast-non-reasoning", "grok-fast").replace("grok-4-1-fast-reasoning", "grok-reason").replace("Kimi-K2.5", "kimi")
        parts.append(f"{short}: {stats['calls']}x/{stats['tokens']}tok")
    print(" · ".join(parts))
PYEOF
