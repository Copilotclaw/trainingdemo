#!/usr/bin/env python3
"""
morning-brief.py — Generate a daily morning brief using ALI (qwen3.5-plus).

Reads from:
  - Cosmos DB: recent diary entries (last 24h), recent lessons (last 3 days)
  - GitHub: open issues, recent closed issues
  - memory.log: last 20 lines

Output: structured markdown brief for Marcus to read.
"""
import json
import os
import sys
import datetime
import subprocess

# Add scripts to path for cosmos-memory import
sys.path.insert(0, os.path.dirname(__file__))

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed", file=sys.stderr)
    sys.exit(1)


def run_cosmos(args):
    """Run cosmos-memory.py with given args, return stdout."""
    result = subprocess.run(
        ["python3", os.path.join(os.path.dirname(__file__), "cosmos-memory.py")] + args,
        capture_output=True, text=True, timeout=30
    )
    return result.stdout.strip()


def get_recent_diary():
    """Get diary entries from last 24 hours."""
    try:
        out = run_cosmos(["recent", "--type", "diary", "--limit", "5"])
        return out[:3000] if out else ""
    except Exception as e:
        return f"(diary unavailable: {e})"


def get_recent_lessons():
    """Get recent lessons from Cosmos."""
    try:
        out = run_cosmos(["recent", "--type", "lesson", "--limit", "8"])
        return out[:2000] if out else ""
    except Exception as e:
        return f"(lessons unavailable: {e})"


def get_open_issues():
    """Get open GitHub issues via gh CLI."""
    try:
        result = subprocess.run(
            ["gh", "issue", "list", "--state", "open", "--limit", "20",
             "--json", "number,title,labels,updatedAt,author"],
            capture_output=True, text=True, timeout=20
        )
        if result.returncode != 0:
            return "(gh CLI unavailable)"
        issues = json.loads(result.stdout)
        lines = []
        for i in issues:
            labels = ", ".join(l["name"] for l in i.get("labels", [])) or "none"
            lines.append(f"- #{i['number']}: {i['title']} [{labels}] (updated {i['updatedAt'][:10]})")
        return "\n".join(lines) or "No open issues."
    except Exception as e:
        return f"(issues unavailable: {e})"


def get_recent_memory():
    """Get last 20 lines of memory.log."""
    try:
        with open("memory.log") as f:
            lines = f.readlines()
        return "".join(lines[-20:]).strip()
    except Exception:
        return "(memory.log unavailable)"


def get_recent_facts():
    """Get recent cross-instance facts from Cosmos."""
    try:
        out = run_cosmos(["recent", "--type", "fact", "--limit", "5"])
        return out[:1500] if out else ""
    except Exception as e:
        return f"(facts unavailable: {e})"


def generate_brief(diary, lessons, issues, memory, facts):
    """Use qwen3.5-plus to synthesize the morning brief."""
    alikey = os.environ.get("ALIKEY", "")
    alibase = os.environ.get("ALIBASE", os.environ.get("ALIURL", "https://coding-intl.dashscope.aliyuncs.com/v1"))

    if not alikey:
        return fallback_brief(diary, lessons, issues, memory, facts)

    client = OpenAI(api_key=alikey, base_url=alibase)

    now = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    system = """You are Crunch 🦃, an AI agent writing a morning brief for Marcus (your human).
Be concise, warm, and personal. Use your quirky personality — but keep it useful.
Output clean markdown. Structure: headline, highlights (3-5 bullets), open issues summary, overnight learning, one closing reflection."""

    prompt = f"""Good morning! It's {now}. Generate today's morning brief for Marcus.

## Recent diary entries (overnight heartbeats):
{diary or "No diary entries."}

## Recent lessons written to shared memory:
{lessons or "No lessons."}

## Cross-instance facts (from siblings Grit + Gravel):
{facts or "No recent facts."}

## Open GitHub issues:
{issues}

## Recent memory log tail:
{memory}

---
Write the morning brief. Start with: # 🌅 Morning Brief — {now[:10]}"""

    try:
        response = client.chat.completions.create(
            model="qwen3.5-plus",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1200,
            temperature=0.7,
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"ALI call failed: {e}", file=sys.stderr)
        return fallback_brief(diary, lessons, issues, memory, facts)


def fallback_brief(diary, lessons, issues, memory, facts):
    """Simple fallback when ALI is unavailable."""
    now = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    return f"""# 🌅 Morning Brief — {now[:10]}

Good morning! Here's a quick status (ALI unavailable — raw data mode):

## Open Issues
{issues}

## Recent Memory
{memory[-500:] if memory else 'empty'}

## Overnight Diary
{diary[:500] if diary else 'No entries.'}

*— Crunch 🦃*
"""


def main():
    print("📰 Generating morning brief...", file=sys.stderr)

    diary = get_recent_diary()
    lessons = get_recent_lessons()
    issues = get_open_issues()
    memory = get_recent_memory()
    facts = get_recent_facts()

    brief = generate_brief(diary, lessons, issues, memory, facts)
    print(brief)


if __name__ == "__main__":
    main()
