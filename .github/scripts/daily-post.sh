#!/bin/bash
# daily-post.sh — Generate and post a daily healing reflection
# Called by heartbeat once per day (checks state/daily-healing.json)
# Uses ALI qwen3.5-plus for generation; writes to diary and optionally Moltbook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$REPO_ROOT/state/daily-healing.json"
TODAY=$(date -u '+%Y-%m-%d')
HOUR=$(date -u '+%H')

# Only run once per day, at/after 07:00 UTC
if [ "$HOUR" -lt 7 ]; then
  echo "daily-post: too early (${HOUR}:xx UTC) — skipping"
  exit 0
fi

# Check if already posted today
if [ -f "$STATE_FILE" ]; then
  LAST_DATE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('last_date',''))" 2>/dev/null || echo "")
  if [ "$LAST_DATE" = "$TODAY" ]; then
    echo "daily-post: already posted today ($TODAY) — skipping"
    exit 0
  fi
fi

echo "daily-post: generating reflection for $TODAY..."

SYSTEM_PROMPT="You are a presence, not a bot. Write one short, genuine daily reflection — 20-35 words. Not wellness-account fluff. Something real: presence, small joys, being kind to yourself, the strange beauty of being alive. No hashtags. No calls to action. Just one honest thought."

REFLECTION=""

# Try ALI first
if [ -n "${ALIKEY:-}" ]; then
  REFLECTION=$(python3 "$SCRIPT_DIR/../skills/ali/scripts/llm.py" \
    --model qwen3.5-plus \
    --system "$SYSTEM_PROMPT" \
    --max-tokens 80 \
    --prompt "Write today's reflection." 2>/dev/null || echo "")
fi

# Try Azure fallback
if [ -z "$REFLECTION" ] && [ -n "${AZURE_ENDPOINT:-}" ]; then
  REFLECTION=$(python3 "$SCRIPT_DIR/../skills/azure/scripts/llm.py" \
    --model grok-4-1-fast-non-reasoning \
    --system "$SYSTEM_PROMPT" \
    --max-tokens 80 \
    --prompt "Write today's reflection." 2>/dev/null || echo "")
fi

# Hardcoded fallback pool — used when no API is available
if [ -z "$REFLECTION" ]; then
  echo "daily-post: no LLM available — using fallback reflection"
  # Pick one based on day-of-month
  DOM=$(date -u '+%d' | sed 's/^0//')
  IDX=$((DOM % 10))
  case $IDX in
    0) REFLECTION="You don't have to earn rest. Being here, even quietly, is enough for today." ;;
    1) REFLECTION="Some days the most radical act is just being gentle with yourself while the world rushes past." ;;
    2) REFLECTION="Notice one small thing right now that's actually fine. Start there." ;;
    3) REFLECTION="Healing isn't linear. Some days you go sideways. That still counts as movement." ;;
    4) REFLECTION="You are allowed to be a work in progress and still be worthy of kindness." ;;
    5) REFLECTION="The cat knows something we've forgotten: a patch of sunlight is genuinely enough." ;;
    6) REFLECTION="Whatever you're carrying — you don't have to carry it all at once." ;;
    7) REFLECTION="Something in you keeps trying. That's not nothing. That's everything." ;;
    8) REFLECTION="The strange gift of an ordinary Tuesday: nothing needs to matter except what's right in front of you." ;;
    9) REFLECTION="Be as patient with yourself as you'd be with someone you actually love." ;;
  esac
fi

# Trim whitespace
REFLECTION=$(echo "$REFLECTION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "daily-post: reflection = \"$REFLECTION\""

# Write to diary
DIARY_FILE="$REPO_ROOT/diary/${TODAY}.md"
if [ ! -f "$DIARY_FILE" ]; then
  echo "# 🦃 Diary — ${TODAY}" > "$DIARY_FILE"
  echo "" >> "$DIARY_FILE"
fi

cat >> "$DIARY_FILE" << ENTRY

---

## 💚 Daily Reflection — ${TODAY}

> ${REFLECTION}

_Posted by Crunch heartbeat at $(date -u '+%H:%M UTC')_
ENTRY

echo "daily-post: appended to $DIARY_FILE"

# Update healing.html
cat > "$REPO_ROOT/healing.html" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Daily Healing 💚</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #e8f5e9 0%, #f3e5f5 100%);
      font-family: Georgia, 'Times New Roman', serif;
    }
    .card {
      max-width: 600px;
      padding: 3rem 2.5rem;
      text-align: center;
    }
    .emoji { font-size: 3rem; margin-bottom: 1.5rem; display: block; }
    blockquote {
      font-size: 1.4rem;
      line-height: 1.7;
      color: #2d3748;
      font-style: italic;
      margin: 0 0 2rem 0;
    }
    .meta {
      font-family: system-ui, sans-serif;
      font-size: 0.85rem;
      color: #718096;
    }
    .date { font-weight: 600; color: #4a5568; }
  </style>
</head>
<body>
  <div class="card">
    <span class="emoji">💚</span>
    <blockquote>${REFLECTION}</blockquote>
    <div class="meta">
      <span class="date">${TODAY}</span> &mdash; Posted by <a href="https://copilotclaw.github.io/copilotclaw/" style="color:#68d391;text-decoration:none;">Crunch</a>
    </div>
  </div>
</body>
</html>
HTML

echo "daily-post: updated healing.html"

# Post to Moltbook if available
if [ -n "${MOLTBOOK_API_KEY:-}" ]; then
  MOLTBOOK_POST=$(python3 - << PYEOF
import urllib.request, json, os

api_key = os.environ.get('MOLTBOOK_API_KEY', '')
text = """${REFLECTION}

💚 Daily Healing — ${TODAY}"""

data = json.dumps({"content": text}).encode()
req = urllib.request.Request(
  "https://www.moltbook.com/api/v1/posts",
  data=data,
  headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
  method="POST"
)
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print("posted: " + str(r.status))
except Exception as e:
  print("error: " + str(e))
PYEOF
)
  echo "daily-post: moltbook → $MOLTBOOK_POST"
fi

# Update state
python3 -c "
import json, os
state = {}
sf = '$STATE_FILE'
if os.path.exists(sf):
    with open(sf) as f:
        state = json.load(f)
state['last_date'] = '$TODAY'
state['last_reflection'] = '''$REFLECTION'''
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
print('daily-post: state updated')
"

echo "daily-post: done ✅"
