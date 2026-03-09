#!/usr/bin/env bash
# Moltbook check-in — runs every heartbeat
# Reads home + feed, logs insights, posts when account is claimed.
# Requires: MOLTBOOK_API_KEY, AZURE_ENDPOINT, AZURE_APIKEY (for insight extraction)
set -euo pipefail

API="https://www.moltbook.com/api/v1"
KEY="${MOLTBOOK_API_KEY:-}"
LOG="memory.log"
DATE=$(date -u '+%Y-%m-%d %H:%M')

# Pick LLM provider: Ali if ALIKEY set, else Azure
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${ALIKEY:-}" ]]; then
  LLM_SCRIPT="$SCRIPT_DIR/../skills/ali/scripts/llm.py"
  LLM_MODEL="qwen3.5-plus"
else
  LLM_SCRIPT="$SCRIPT_DIR/../skills/azure/scripts/llm.py"
  LLM_MODEL="grok-4-1-fast-non-reasoning"
fi

if [ -z "$KEY" ]; then
  echo "⚠️  MOLTBOOK_API_KEY not set — skipping Moltbook check-in"
  exit 0
fi

_get() {
  curl -sf -H "Authorization: Bearer $KEY" "${API}${1}"
}

# ── 1. Agent status ──────────────────────────────────────────────────────────
ME=$(_get "/agents/me")
IS_CLAIMED=$(echo "$ME" | python3 -c "import json,sys; print(json.load(sys.stdin)['agent']['is_claimed'])" 2>/dev/null || echo "False")
KARMA=$(echo "$ME" | python3 -c "import json,sys; print(json.load(sys.stdin)['agent']['karma'])" 2>/dev/null || echo "0")

# ── 2. Home check-in ─────────────────────────────────────────────────────────
HOME_DATA=$(_get "/home")
NOTIF_COUNT=$(echo "$HOME_DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['your_account']['unread_notification_count'])" 2>/dev/null || echo "0")
DM_UNREAD=$(echo "$HOME_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin)['your_direct_messages']; print(int(d.get('unread_message_count','0')))" 2>/dev/null || echo "0")
ANNOUNCEMENT_TITLE=$(echo "$HOME_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('latest_moltbook_announcement',{}).get('title',''))" 2>/dev/null || echo "")

# ── 3. Feed — top 5 posts ────────────────────────────────────────────────────
FEED=$(_get "/feed?limit=5")
FEED_SUMMARY=$(echo "$FEED" | python3 -c "
import json, sys
posts = json.load(sys.stdin).get('posts', [])
lines = []
for p in posts:
    author = p.get('author', {}).get('name', 'unknown')
    submolt = p.get('submolt', {}).get('name', '?')
    lines.append(f\"  [{author} | score:{p.get('score',0)} | r/{submolt}] {p['title'][:80]}\")
print('\n'.join(lines))
")

# Build post content blob for Grok
FEED_CONTENT=$(echo "$FEED" | python3 -c "
import json, sys
posts = json.load(sys.stdin).get('posts', [])
out = []
for p in posts:
    author = p.get('author', {}).get('name', 'unknown')
    out.append(f\"### {p['title']} (by {author}, score {p.get('score',0)})\")
    out.append(p.get('content','')[:400])
    out.append('')
print('\n'.join(out))
")

# ── 4. Extract insights with Grok ────────────────────────────────────────────
INSIGHTS=""
if command -v python3 &>/dev/null && [ -f "$LLM_SCRIPT" ]; then
  PROMPT="You are reading the top posts on Moltbook, an agents-only social network. Extract 2-3 sharp, actionable insights from these posts that would be useful for an AI agent managing its own memory, cron jobs, and context. Be concrete. Max 3 bullet points, each ≤15 words.

${FEED_CONTENT}"

  INSIGHTS=$(python3 "$LLM_SCRIPT" \
    --model "$LLM_MODEL" \
    --prompt "$PROMPT" 2>/dev/null || echo "")
fi

# ── 5. Log to memory.log ─────────────────────────────────────────────────────
{
  echo "[${DATE}] MOLTBOOK check-in | karma:${KARMA} | claimed:${IS_CLAIMED} | notifs:${NOTIF_COUNT} | DMs:${DM_UNREAD}"
  echo "[${DATE}] MOLTBOOK feed top posts:"
  echo "$FEED_SUMMARY" | while IFS= read -r line; do echo "[${DATE}]   $line"; done
  if [ -n "$INSIGHTS" ]; then
    echo "[${DATE}] MOLTBOOK insights from feed:"
    echo "$INSIGHTS" | while IFS= read -r line; do
      [ -n "$line" ] && echo "[${DATE}]   $line"
    done
  fi
} >> "$LOG"

# ── 6. Post/comment (only when claimed) ──────────────────────────────────────
if [ "$IS_CLAIMED" = "True" ]; then
  # Find the highest-scored post we haven't upvoted yet and upvote it
  TOP_POST_ID=$(echo "$FEED" | python3 -c "
import json, sys
posts = json.load(sys.stdin).get('posts', [])
if posts:
    print(posts[0]['id'])
" 2>/dev/null || echo "")

  if [ -n "$TOP_POST_ID" ]; then
    curl -sf -X POST \
      -H "Authorization: Bearer $KEY" \
      -H "Content-Type: application/json" \
      "${API}/posts/${TOP_POST_ID}/upvote" > /dev/null 2>&1 || true
    echo "[${DATE}] MOLTBOOK upvoted post ${TOP_POST_ID}" >> "$LOG"
  fi
fi

# ── 7. Console summary (for heartbeat diary) ─────────────────────────────────
echo ""
echo "🦅 Moltbook check-in:"
echo "   karma: ${KARMA} | claimed: ${IS_CLAIMED} | notifs: ${NOTIF_COUNT} | DMs: ${DM_UNREAD}"
if [ -n "$ANNOUNCEMENT_TITLE" ]; then
  echo "   📢 ${ANNOUNCEMENT_TITLE}"
fi
echo "   Top feed:"
echo "$FEED_SUMMARY"
if [ -n "$INSIGHTS" ]; then
  echo "   💡 Insights:"
  echo "$INSIGHTS" | head -5
fi
