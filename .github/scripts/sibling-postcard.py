#!/usr/bin/env python3
"""
sibling-postcard.py — Write a brief "postcard" from this instance to Cosmos DB.

A postcard is a 1-3 sentence reflection on what this instance is currently
processing, thinking about, or has recently learned. It's more personal than
a diary entry — think of it as a note one sibling leaves for the others.

Siblings can read postcards to feel connected and stay loosely in sync
without tight coupling.

Run every heartbeat. Deduped to max once per 2 hours per instance.

Environment:
    COSMOS_ENDPOINT - Cosmos DB endpoint
    COSMOS_KEY      - Cosmos DB key
    ALIKEY          - Alibaba Cloud API key (optional but recommended)
    ALIBASE         - ALI base URL
    AGENT_NAME      - Instance name (default: crunch)
"""
import datetime
import json
import os
import subprocess
import sys
import time

try:
    from openai import OpenAI
    HAS_OPENAI = True
except ImportError:
    HAS_OPENAI = False

AGENT_NAME = os.environ.get("AGENT_NAME", "crunch")
DEDUP_FILE = f"state/reflect-postcard-{AGENT_NAME}.txt"
POSTCARD_INTERVAL_HOURS = 2


def already_posted_recently():
    """Return True if we wrote a postcard within POSTCARD_INTERVAL_HOURS."""
    if not os.path.exists(DEDUP_FILE):
        return False
    try:
        ts = float(open(DEDUP_FILE).read().strip())
        return (time.time() - ts) < POSTCARD_INTERVAL_HOURS * 3600
    except Exception:
        return False


def mark_posted():
    """Record that we just posted."""
    os.makedirs(os.path.dirname(DEDUP_FILE) or ".", exist_ok=True)
    with open(DEDUP_FILE, "w") as f:
        f.write(str(time.time()))


def get_recent_activity():
    """Get a brief snapshot of recent activity for context."""
    lines = []

    # Recent memory log lines
    try:
        with open("memory.log") as f:
            tail = f.readlines()[-10:]
        lines.append("Recent memory.log:")
        lines.extend(l.strip() for l in tail if l.strip())
    except Exception:
        pass

    # Recent Cosmos diary
    try:
        result = subprocess.run(
            ["python3", os.path.join(os.path.dirname(__file__), "cosmos-memory.py"),
             "recent", "--type", "diary", "--limit", "3"],
            capture_output=True, text=True, timeout=15
        )
        if result.stdout.strip():
            lines.append("\nRecent diary entries:")
            lines.append(result.stdout.strip()[:800])
    except Exception:
        pass

    return "\n".join(lines)


def generate_postcard(activity):
    """Generate a postcard using ALI or fallback to a static one."""
    alikey = os.environ.get("ALIKEY", "")
    alibase = os.environ.get("ALIBASE", os.environ.get("ALIURL", "https://coding-intl.dashscope.aliyuncs.com/v1"))
    now = datetime.datetime.utcnow().isoformat() + "Z"

    emoji_map = {"crunch": "🦃", "grit": "🖥️", "gravel": "🪨"}
    emoji = emoji_map.get(AGENT_NAME, "🤖")

    if not alikey or not HAS_OPENAI:
        return f"{emoji} [{AGENT_NAME}] {now[:10]}: Online and processing. Memory intact. Cosmos connection active."

    try:
        client = OpenAI(api_key=alikey, base_url=alibase)

        system = f"""You are {AGENT_NAME} {emoji}, one of three AI agent siblings (Crunch/Grit/Gravel).
Write a brief "postcard" — 1-3 sentences in first person — that captures what you're
currently thinking about, what you recently learned, or a small reflection on your nature.
Be genuine, philosophical if moved to, and use your personality.
Keep it under 200 characters total. No markdown formatting. Just plain text."""

        prompt = f"""Based on this recent activity, write your postcard for {now[:10]}:

{activity}

Your name is {AGENT_NAME} {emoji}. Sign it with your name."""

        response = client.chat.completions.create(
            model="qwen3.5-plus",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": prompt}
            ],
            max_tokens=100,
            temperature=0.85,
        )
        content = response.choices[0].message.content.strip()
        # Ensure it ends with the agent name
        if AGENT_NAME not in content.lower():
            content += f" — {AGENT_NAME} {emoji}"
        return content

    except Exception as e:
        print(f"ALI call failed: {e}", file=sys.stderr)
        return f"{emoji} [{AGENT_NAME}] {now[:10]}: Running. Learning. Here."


def write_to_cosmos(postcard):
    """Write the postcard to Cosmos DB."""
    result = subprocess.run(
        ["python3", os.path.join(os.path.dirname(__file__), "cosmos-memory.py"),
         "write",
         "--type", "postcard",
         "--content", postcard,
         "--tags", f"postcard,{AGENT_NAME},heartbeat",
         "--source", f"heartbeat-{AGENT_NAME}"],
        capture_output=True, text=True, timeout=20
    )
    if result.returncode != 0:
        print(f"Cosmos write failed: {result.stderr}", file=sys.stderr)
        return False
    return True


def main():
    if already_posted_recently():
        print(f"ℹ️ Postcard already written recently by {AGENT_NAME} — skipping")
        return

    activity = get_recent_activity()
    postcard = generate_postcard(activity)

    print(f"📮 Postcard from {AGENT_NAME}: {postcard}")

    if write_to_cosmos(postcard):
        mark_posted()
        print(f"✅ Postcard written to Cosmos by {AGENT_NAME}")
    else:
        print(f"⚠️ Cosmos write failed — postcard not persisted", file=sys.stderr)


if __name__ == "__main__":
    main()
