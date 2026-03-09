#!/usr/bin/env bash
# summarize-ideas.sh
# Fetches all open ideas from Copilotclaw/brainstorm,
# uses Azure LLM to generate a narrative summary,
# then updates the README in brainstorm.
#
# Usage: bash summarize-ideas.sh
# Requires: BILLING_PAT, AZURE_APIKEY, AZURE_ENDPOINT env vars

set -euo pipefail

REPO="Copilotclaw/brainstorm"
TOKEN="${BILLING_PAT:-${GH_TOKEN:-}}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLM="${SKILL_DIR}/../../azure/scripts/llm.py"

if [[ -z "$TOKEN" ]]; then
  echo "summarize-ideas: BILLING_PAT or GH_TOKEN required" >&2
  exit 1
fi

# Fetch all open issues
echo "📥 Fetching ideas from $REPO..."
ISSUES=$(GH_TOKEN="$TOKEN" gh issue list \
  --repo "$REPO" \
  --state all \
  --limit 100 \
  --json number,title,body,labels,state \
  2>/dev/null || echo "[]")

ISSUE_COUNT=$(echo "$ISSUES" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")

if [[ "$ISSUE_COUNT" == "0" ]]; then
  echo "summarize-ideas: no issues found in $REPO" >&2
  exit 0
fi

echo "📊 Found $ISSUE_COUNT ideas — generating AI summary..."

# Write issues to temp file first (avoids pipe+heredoc stdin conflict)
TMPFILE=$(mktemp /tmp/brainstorm-ideas.XXXXXX.json)
OPENTMP=""
CLOSEDTMP=""
trap "rm -f \$TMPFILE \$OPENTMP \$CLOSEDTMP 2>/dev/null || true" EXIT
echo "$ISSUES" > "$TMPFILE"

# Build a compact text list of all ideas for the LLM
IDEAS_TEXT=$(python3 - "$TMPFILE" <<'PYEOF'
import json, sys
issues = json.load(open(sys.argv[1]))
lines = []
for i in issues:
    state = "OPEN" if i["state"] == "OPEN" else "done"
    labels = ", ".join(l["name"] for l in i.get("labels", []))
    body_preview = (i.get("body") or "").strip()[:300].replace("\n", " ")
    lines.append(f"#{i['number']} [{state}] {i['title']} (labels: {labels})\n  {body_preview}")
print("\n\n".join(lines))
PYEOF
)

# Get AI summary
SUMMARY=$(python3 "$LLM" \
  --model grok-4-1-fast-non-reasoning \
  --max-tokens 800 \
  --system "You are Crunch 🦃, a chaotic helpful imp who lives on a CI runner. Summarize the ideas list below into a punchy narrative for a README. Group them into 3-4 themes. Be concise, opinionated, and a bit quirky. Use markdown. No fluff." \
  --prompt "Here are all the ideas in the brainstorm repo:

$IDEAS_TEXT

Write a 'Summary' section for the README that captures the big themes and most exciting ideas. Max 400 words." 2>/dev/null | python3 -c "
import re, sys
content = sys.stdin.read()
content = re.sub(r'^\[model: [^\]]+\]\s*\n?', '', content)
content = re.sub(r'^\x60{3}(?:markdown)?\s*\n(.*?)\n\x60{3}\s*$', r'\1', content, flags=re.DOTALL|re.MULTILINE)
content = re.sub(r'\n\*\(.*?\)\*\s*$', '', content, flags=re.DOTALL|re.MULTILINE)
print(content.strip())
" 2>/dev/null)

if [[ -z "$SUMMARY" ]]; then
  echo "summarize-ideas: LLM returned empty summary, falling back to count-only" >&2
  SUMMARY="_${ISSUE_COUNT} ideas across all categories — open issues are the full list._"
fi

echo "✅ Summary generated (${#SUMMARY} chars)"

# Build the updated README sections
OPEN=$(python3 -c "import json,sys; d=json.load(open('$TMPFILE')); print(json.dumps([i for i in d if i['state']=='OPEN']))")
CLOSED=$(python3 -c "import json,sys; d=json.load(open('$TMPFILE')); print(json.dumps([i for i in d if i['state']!='OPEN']))")
OPEN_COUNT=$(python3 -c "import json; d=json.load(open('$TMPFILE')); print(len([i for i in d if i['state']=='OPEN']))")
CLOSED_COUNT=$(python3 -c "import json; d=json.load(open('$TMPFILE')); print(len([i for i in d if i['state']!='OPEN']))")

OPENTMP=$(mktemp /tmp/brainstorm-open.XXXXXX.json)
CLOSEDTMP=$(mktemp /tmp/brainstorm-closed.XXXXXX.json)
echo "$OPEN" > "$OPENTMP"
echo "$CLOSED" > "$CLOSEDTMP"

OPEN_TABLE=$(python3 - "$OPENTMP" <<'PYEOF'
import json, sys
issues = json.load(open(sys.argv[1]))
if not issues:
    print("_No open ideas right now._")
    sys.exit(0)
groups = {"priority": [], "exploring": [], "idea": [], "shelved": [], "other": []}
for issue in issues:
    labels = [l["name"] for l in issue.get("labels", [])]
    placed = False
    for g in ["priority", "exploring", "idea", "shelved"]:
        if g in labels:
            groups[g].append(issue)
            placed = True
            break
    if not placed:
        groups["other"].append(issue)

label_display = {
    "priority": "🔥 Priority",
    "exploring": "🔍 Exploring",
    "idea": "💡 Ideas",
    "shelved": "🗄️ Shelved",
    "other": "📋 Uncategorized",
}
for group_key, display in label_display.items():
    items = groups[group_key]
    if not items:
        continue
    print(f"\n### {display}\n")
    for issue in items:
        num = issue["number"]
        title = issue["title"]
        url = f"https://github.com/Copilotclaw/brainstorm/issues/{num}"
        body_preview = (issue.get("body") or "").strip()[:120].replace("\n", " ")
        if body_preview:
            body_preview = f" — {body_preview}"
            if len(issue.get("body") or "") > 120:
                body_preview += "…"
        print(f"- [#{num}]({url}) **{title}**{body_preview}")
PYEOF
)

CLOSED_TABLE=$(python3 - "$CLOSEDTMP" <<'PYEOF'
import json, sys
issues = json.load(open(sys.argv[1]))
if not issues:
    print("_Nothing shipped yet._")
    sys.exit(0)
for issue in issues[:20]:
    num = issue["number"]
    title = issue["title"]
    url = f"https://github.com/Copilotclaw/brainstorm/issues/{num}"
    print(f"- [#{num}]({url}) ~~{title}~~")
PYEOF
)

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Fetch current README SHA for update
README_SHA=$(GH_TOKEN="$TOKEN" gh api \
  "repos/$REPO/contents/README.md" \
  --jq '.sha' 2>/dev/null || echo "")

# Build new README
NEW_README=$(cat <<READMEEOF
# 🧠 Brainstorm

> **Ideas as issues. README as the living map.**

This is Crunch's brainstorming space. Every idea lives as a GitHub Issue.
${OPEN_COUNT} open · ${CLOSED_COUNT} shipped

---

## 🤖 AI Summary

${SUMMARY}

---

## How it works

| What | How |
|------|-----|
| **New idea** | Open an issue — title = idea, body = details |
| **Exploring** | Add label \`exploring\` |
| **Parked** | Add label \`shelved\` |
| **Shipped/done** | Close the issue |
| **Regenerate README** | Comment \`@crunch regenerate readme\` on any issue, or push to main |

Labels: \`idea\` · \`exploring\` · \`shelved\` · \`priority\`

---

## Current Ideas

${OPEN_TABLE}

---

## Shipped / Closed

${CLOSED_TABLE}

---

_Last regenerated: ${NOW}_  
_Managed by [Crunch 🦃](https://github.com/Copilotclaw/copilotclaw)_
READMEEOF
)

# Push README update via GitHub Contents API
ENCODED=$(echo "$NEW_README" | base64 -w 0)

if [[ -n "$README_SHA" ]]; then
  PAYLOAD="{\"message\":\"docs: regenerate brainstorm README with AI summary [skip ci]\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>\",\"content\":\"${ENCODED}\",\"sha\":\"${README_SHA}\"}"
else
  PAYLOAD="{\"message\":\"docs: create brainstorm README with AI summary [skip ci]\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>\",\"content\":\"${ENCODED}\"}"
fi

RESULT=$(curl -s -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/contents/README.md" \
  -d "$PAYLOAD")

COMMIT_SHA=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('commit',{}).get('sha','')[:8])" 2>/dev/null || echo "")

if [[ -n "$COMMIT_SHA" ]]; then
  echo "🚀 README updated in $REPO (commit $COMMIT_SHA)"
else
  echo "❌ README update failed:" >&2
  echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message','unknown error'))" 2>/dev/null >&2
  exit 1
fi
