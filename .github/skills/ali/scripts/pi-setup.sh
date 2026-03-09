#!/usr/bin/env bash
# Setup PI coding agent with DashScope as a custom OpenAI-compatible provider.
# Idempotent — safe to run multiple times.
# Usage: source this script or run it directly before using pi-llm.py

set -euo pipefail

PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
MODELS_JSON="$PI_AGENT_DIR/models.json"

# Install PI if not present
if ! command -v pi &>/dev/null; then
    echo "[pi-setup] Installing @mariozechner/pi-coding-agent..." >&2
    npm install -g @mariozechner/pi-coding-agent >/dev/null 2>&1
    echo "[pi-setup] PI installed: $(pi --version)" >&2
else
    echo "[pi-setup] PI already installed: $(pi --version)" >&2
fi

# Configure DashScope provider if not already done
mkdir -p "$PI_AGENT_DIR"

if [ ! -f "$MODELS_JSON" ] || ! python3 -c "
import json, sys
d = json.load(open('$MODELS_JSON'))
assert 'dashscope' in d.get('providers', {})
" 2>/dev/null; then
    echo "[pi-setup] Writing $MODELS_JSON with DashScope provider..." >&2
    cat > "$MODELS_JSON" <<'MODELS'
{
  "providers": {
    "dashscope": {
      "baseUrl": "https://coding-intl.dashscope.aliyuncs.com/v1",
      "api": "openai-completions",
      "apiKey": "ALIKEY",
      "models": [
        {
          "id": "qwen3-coder-plus",
          "name": "Qwen3 Coder Plus (DashScope)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 131072,
          "maxTokens": 8192,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        },
        {
          "id": "qwen3.5-plus",
          "name": "Qwen3.5 Plus (DashScope)",
          "reasoning": true,
          "input": ["text", "image"],
          "contextWindow": 131072,
          "maxTokens": 8192,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        },
        {
          "id": "qwen3-coder-next",
          "name": "Qwen3 Coder Next (DashScope)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 131072,
          "maxTokens": 8192,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
MODELS
    echo "[pi-setup] DashScope provider configured." >&2
else
    echo "[pi-setup] DashScope provider already configured." >&2
fi
