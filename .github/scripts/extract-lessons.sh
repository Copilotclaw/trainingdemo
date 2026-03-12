#!/bin/bash
# extract-lessons.sh — Post-session lesson extraction via LLM → Cosmos DB
#
# Usage: extract-lessons.sh <issue_number> [thread_file]
#
# Env (required for Cosmos writes):
#   COSMOS_ENDPOINT, COSMOS_KEY
# Env (LLM — at least one pair required):
#   ALIKEY (+ optional ALIBASE/ALIURL) — Alibaba Cloud DashScope (preferred)
#   AZURE_ENDPOINT + AZURE_APIKEY     — Azure fallback via grok
#
# Also reads /tmp/agent-response.txt if present (enriches extraction context).
set -euo pipefail

ISSUE_NUMBER="${1:-}"
THREAD_FILE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "Usage: extract-lessons.sh <issue_number> [thread_file]"
  exit 1
fi

if [[ -z "${COSMOS_ENDPOINT:-}" || -z "${COSMOS_KEY:-}" ]]; then
  echo "[extract-lessons] Skipping: COSMOS_ENDPOINT or COSMOS_KEY not set"
  exit 0
fi

if [[ -z "${ALIKEY:-}" && ( -z "${AZURE_ENDPOINT:-}" || -z "${AZURE_APIKEY:-}" ) ]]; then
  echo "[extract-lessons] Skipping: no LLM credentials (need ALIKEY or AZURE_ENDPOINT+AZURE_APIKEY)"
  exit 0
fi

# Install openai if needed (silent)
pip3 install openai -q --break-system-packages 2>/dev/null || pip install openai -q 2>/dev/null || true

# Get thread content — write to a temp file to avoid shell quoting issues
THREAD_TMP=$(mktemp)

if [[ -n "$THREAD_FILE" && -f "$THREAD_FILE" ]]; then
  head -c 10000 "$THREAD_FILE" > "$THREAD_TMP"
elif command -v gh &>/dev/null; then
  gh issue view "$ISSUE_NUMBER" --comments --json title,body,comments \
    --jq '"# " + .title + "\n\n" + .body + "\n\n## Comments\n\n" + ([.comments[].body] | join("\n\n---\n\n"))' \
    2>/dev/null | head -c 10000 > "$THREAD_TMP" || true
fi

if [[ ! -s "$THREAD_TMP" ]]; then
  echo "⚠️  No thread content for issue #$ISSUE_NUMBER — skipping lesson extraction"
  rm -f "$THREAD_TMP"
  exit 0
fi

echo "[extract-lessons] Extracting lessons for issue #${ISSUE_NUMBER}..."

# Copy agent response if present
AGENT_TMP=$(mktemp)
if [[ -f /tmp/agent-response.txt ]]; then
  head -c 3000 /tmp/agent-response.txt > "$AGENT_TMP"
fi

LESSONS_FILE=$(mktemp)

# Use Python for LLM call — reads from temp files, no shell quoting issues
python3 - "$THREAD_TMP" "$AGENT_TMP" "$LESSONS_FILE" "$ISSUE_NUMBER" \
  "${ALIKEY:-}" "${ALIBASE:-${ALIURL:-https://coding-intl.dashscope.aliyuncs.com/v1}}" \
  "${AZURE_ENDPOINT:-}" "${AZURE_APIKEY:-}" <<'PYEOF'
import sys, os, json

thread_file, agent_file, lessons_file, issue_number, alikey, alibase, azure_endpoint, azure_apikey = sys.argv[1:]

with open(thread_file, 'r', errors='replace') as f:
    thread = f.read()

agent_response = ''
if os.path.getsize(agent_file) > 0:
    with open(agent_file, 'r', errors='replace') as f:
        agent_response = f.read()

system_msg = (
    "You are a technical lesson extractor for an AI agent system called Crunch/Grit. "
    "Output ONLY valid JSON arrays, no markdown, no commentary."
)

user_msg = (
    "Analyze this agent session and extract up to 3 key lessons worth remembering.\n\n"
    "Focus on:\n"
    "- Tools or commands that failed or were blocked (shell expansions, MCP errors, auth)\n"
    "- Patterns or approaches that worked well\n"
    "- Bugs found and fixed — what was wrong and how it was corrected\n"
    "- Infrastructure / workflow gotchas discovered\n"
    "- Surprising behavior or API quirks\n"
    "- Explicit user feedback (e.g. 'done', 'perfect', 'wrong approach') — treat as preference/feedback lesson\n\n"
    "Do NOT extract trivial or already well-known observations.\n\n"
    "Output ONLY a valid JSON array. No markdown, no preamble.\n"
    "Max 3 items. Format:\n"
    '[{"what_happened": "brief context (1 sentence)", "lesson": "actionable takeaway (1-2 sentences)", '
    '"category": "tooling|workflow|bug|pattern|infra|api|preference|feedback"}]\n\n'
    "If nothing noteworthy: output []\n\n"
    "---\n"
    f"Issue thread:\n{thread}\n"
)
if agent_response:
    user_msg += f"\n---\nAgent response from this session:\n{agent_response}\n"

def try_ali():
    from openai import OpenAI
    client = OpenAI(api_key=alikey, base_url=alibase)
    resp = client.chat.completions.create(
        model='qwen3-coder-plus',
        messages=[{"role": "system", "content": system_msg}, {"role": "user", "content": user_msg}],
        max_tokens=1024, temperature=0.1,
    )
    return (resp.choices[0].message.content or '').strip()

def try_azure():
    from openai import OpenAI
    client = OpenAI(api_key=azure_apikey, base_url=azure_endpoint)
    resp = client.chat.completions.create(
        model='grok-4-1-fast-non-reasoning',
        messages=[{"role": "system", "content": system_msg}, {"role": "user", "content": user_msg}],
        max_tokens=1024, temperature=0.1,
    )
    return (resp.choices[0].message.content or '').strip()

raw = ''
if alikey:
    try:
        raw = try_ali()
        print(f'[extract-lessons] qwen3-coder-plus responded ({len(raw)} chars)')
    except Exception as e:
        print(f'[extract-lessons] qwen3-coder-plus failed: {e}', file=sys.stderr)

if not raw and azure_endpoint and azure_apikey:
    try:
        raw = try_azure()
        print(f'[extract-lessons] grok fallback responded ({len(raw)} chars)')
    except Exception as e:
        print(f'[extract-lessons] grok fallback failed: {e}', file=sys.stderr)

# Strip markdown fences
if '`' in raw:
    lines = raw.split('\n')
    raw = '\n'.join(l for l in lines if not l.strip().startswith('```'))

with open(lessons_file, 'w') as f:
    f.write(raw.strip())
PYEOF

rm -f "$THREAD_TMP" "$AGENT_TMP"

if [[ ! -s "$LESSONS_FILE" ]]; then
  echo "[extract-lessons] Empty LLM response — no lessons written"
  rm -f "$LESSONS_FILE"
  exit 0
fi

# Parse JSON and write each lesson to Cosmos via learn.sh
python3 - "$LESSONS_FILE" "$ISSUE_NUMBER" "$SCRIPT_DIR" <<'PYEOF'
import json, subprocess, sys

lessons_file, issue_number, script_dir = sys.argv[1:]

with open(lessons_file, 'r') as f:
    raw = f.read().strip()

try:
    lessons = json.loads(raw)
except Exception as e:
    print(f'[extract-lessons] JSON parse error: {e} | raw: {raw[:200]}')
    sys.exit(0)

if not isinstance(lessons, list) or not lessons:
    print('[extract-lessons] No lessons to write (routine session or empty array)')
    sys.exit(0)

count = 0
for lesson in lessons[:3]:
    if not isinstance(lesson, dict):
        continue
    what = str(lesson.get('what_happened', '')).strip()
    learned = str(lesson.get('lesson', '')).strip()
    category = str(lesson.get('category', 'pattern')).strip()
    if not what or not learned:
        continue
    tags = f'session,auto-extract,issue-{issue_number}'
    r = subprocess.run(
        ['bash', f'{script_dir}/learn.sh', 'write', what, learned, category, tags],
        capture_output=True, text=True
    )
    if r.returncode == 0:
        print(f'[extract-lessons] ✅ [{category}] {learned[:80]}')
        count += 1
    else:
        print(f'[extract-lessons] ⚠️  write failed: {r.stderr[:100]}')

print(f'[extract-lessons] Done — {count} lesson(s) written to Cosmos DB for issue #{issue_number}')
PYEOF

rm -f "$LESSONS_FILE"

ISSUE_NUMBER="${1:-}"
THREAD_FILE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "Usage: extract-lessons.sh <issue_number> [thread_file]"
  exit 1
fi

if [[ -z "${COSMOS_ENDPOINT:-}" || -z "${COSMOS_KEY:-}" ]]; then
  echo "[extract-lessons] Skipping: COSMOS_ENDPOINT or COSMOS_KEY not set"
  exit 0
fi

if [[ -z "${ALIKEY:-}" && ( -z "${AZURE_ENDPOINT:-}" || -z "${AZURE_APIKEY:-}" ) ]]; then
  echo "[extract-lessons] Skipping: no LLM credentials (need ALIKEY or AZURE_ENDPOINT+AZURE_APIKEY)"
  exit 0
fi

# Install openai if needed (silent)
pip3 install openai -q --break-system-packages 2>/dev/null || pip install openai -q 2>/dev/null || true

# Get thread content
THREAD=""
if [[ -n "$THREAD_FILE" && -f "$THREAD_FILE" ]]; then
  THREAD=$(head -c 10000 "$THREAD_FILE")
elif command -v gh &>/dev/null; then
  THREAD=$(gh issue view "$ISSUE_NUMBER" --comments --json title,body,comments \
    --jq '"# " + .title + "\n\n" + .body + "\n\n## Comments\n\n" + ([.comments[].body] | join("\n\n---\n\n"))' \
    2>/dev/null | head -c 10000) || THREAD=""
fi

if [[ -z "$THREAD" ]]; then
  echo "⚠️  No thread content for issue #$ISSUE_NUMBER — skipping lesson extraction"
  exit 0
fi

# Optionally include agent's own response as context
AGENT_RESPONSE=""
if [[ -f /tmp/agent-response.txt ]]; then
  AGENT_RESPONSE=$(head -c 3000 /tmp/agent-response.txt)
fi

echo "[extract-lessons] Extracting lessons for issue #${ISSUE_NUMBER}..."

LESSONS_FILE=$(mktemp)

# Use Python for LLM call (avoids shell quoting issues with multi-line prompts)
python3 - <<PYEOF
import os, sys, json

issue_number = '${ISSUE_NUMBER}'
thread = """${THREAD//\"/\\\"}"""
agent_response = """${AGENT_RESPONSE//\"/\\\"}"""
lessons_file = '${LESSONS_FILE}'

alikey = os.environ.get('ALIKEY', '')
alibase = os.environ.get('ALIBASE', os.environ.get('ALIURL', 'https://coding-intl.dashscope.aliyuncs.com/v1'))
azure_endpoint = os.environ.get('AZURE_ENDPOINT', '')
azure_apikey = os.environ.get('AZURE_APIKEY', '')

system_msg = (
    "You are a technical lesson extractor for an AI agent system called Crunch/Grit. "
    "Output ONLY valid JSON arrays, no markdown, no commentary."
)

user_msg = (
    "Analyze this agent session and extract up to 3 key lessons worth remembering.\n\n"
    "Focus on:\n"
    "- Tools or commands that failed or were blocked (shell expansions, MCP errors, auth)\n"
    "- Patterns or approaches that worked well\n"
    "- Bugs found and fixed — what was wrong and how it was corrected\n"
    "- Infrastructure / workflow gotchas discovered\n"
    "- Surprising behavior or API quirks\n"
    "- Explicit user feedback (e.g. 'done', 'perfect', 'wrong approach') — treat as preference/feedback lesson\n\n"
    "Do NOT extract trivial or already well-known observations.\n\n"
    "Output ONLY a valid JSON array. No markdown, no preamble.\n"
    "Max 3 items. Format:\n"
    '[{"what_happened": "brief context (1 sentence)", "lesson": "actionable takeaway (1-2 sentences)", '
    '"category": "tooling|workflow|bug|pattern|infra|api|preference|feedback"}]\n\n'
    "If nothing noteworthy: output []\n\n"
    "---\n"
    f"Issue thread:\n{thread}\n"
)
if agent_response:
    user_msg += f"\n---\nAgent response from this session:\n{agent_response}\n"

def try_ali():
    from openai import OpenAI
    client = OpenAI(api_key=alikey, base_url=alibase)
    resp = client.chat.completions.create(
        model='qwen3-coder-plus',
        messages=[{"role":"system","content":system_msg},{"role":"user","content":user_msg}],
        max_tokens=1024, temperature=0.1,
    )
    return (resp.choices[0].message.content or '').strip()

def try_azure():
    from openai import OpenAI
    client = OpenAI(api_key=azure_apikey, base_url=azure_endpoint)
    resp = client.chat.completions.create(
        model='grok-4-1-fast-non-reasoning',
        messages=[{"role":"system","content":system_msg},{"role":"user","content":user_msg}],
        max_tokens=1024, temperature=0.1,
    )
    return (resp.choices[0].message.content or '').strip()

raw = ''
if alikey:
    try:
        raw = try_ali()
        print(f'[extract-lessons] qwen3-coder-plus responded ({len(raw)} chars)')
    except Exception as e:
        print(f'[extract-lessons] qwen3-coder-plus failed: {e}', file=sys.stderr)

if not raw and azure_endpoint and azure_apikey:
    try:
        raw = try_azure()
        print(f'[extract-lessons] grok fallback responded ({len(raw)} chars)')
    except Exception as e:
        print(f'[extract-lessons] grok fallback failed: {e}', file=sys.stderr)

# Strip markdown fences
if raw.startswith('\`\`\`'):
    lines = raw.split('\n')
    raw = '\n'.join(l for l in lines if not l.startswith('\`\`\`'))

with open(lessons_file, 'w') as f:
    f.write(raw.strip())
PYEOF

if [[ ! -s "$LESSONS_FILE" ]]; then
  echo "[extract-lessons] Empty LLM response — no lessons written"
  rm -f "$LESSONS_FILE"
  exit 0
fi

# Parse JSON and write each lesson to Cosmos via learn.sh
python3 - <<PYEOF
import json, subprocess, sys

lessons_file = '${LESSONS_FILE}'
issue_number = '${ISSUE_NUMBER}'
script_dir = '${SCRIPT_DIR}'

with open(lessons_file, 'r') as f:
    raw = f.read().strip()

try:
    lessons = json.loads(raw)
except Exception as e:
    print(f'[extract-lessons] JSON parse error: {e} | raw: {raw[:200]}')
    sys.exit(0)

if not isinstance(lessons, list) or not lessons:
    print('[extract-lessons] No lessons to write (routine session or empty array)')
    sys.exit(0)

count = 0
for lesson in lessons[:3]:
    if not isinstance(lesson, dict):
        continue
    what = str(lesson.get('what_happened', '')).strip()
    learned = str(lesson.get('lesson', '')).strip()
    category = str(lesson.get('category', 'pattern')).strip()
    if not what or not learned:
        continue
    tags = f'session,auto-extract,issue-{issue_number}'
    r = subprocess.run(
        ['bash', f'{script_dir}/learn.sh', 'write', what, learned, category, tags],
        capture_output=True, text=True
    )
    if r.returncode == 0:
        print(f'[extract-lessons] ✅ [{category}] {learned[:80]}')
        count += 1
    else:
        print(f'[extract-lessons] ⚠️  write failed: {r.stderr[:100]}')

print(f'[extract-lessons] Done — {count} lesson(s) written to Cosmos DB for issue #{issue_number}')
PYEOF

rm -f "$LESSONS_FILE"
