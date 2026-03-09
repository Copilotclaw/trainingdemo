#!/usr/bin/env python3
"""
heartbeat-grok.py — Lightweight heartbeat using grok (free).

Used when quota is high or no complex work is pending.
Reads repo state, writes a brief diary entry, handles routine closes.

Usage:
    python heartbeat-grok.py

Output:
    Diary text to stdout.
    Exits 0 on success.

Environment:
    AZURE_ENDPOINT, AZURE_APIKEY  — Azure AI credentials
    GH_TOKEN / GITHUB_TOKEN       — GitHub auth
    GITHUB_REPOSITORY             — owner/repo
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "lib"))

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
# Pick LLM provider: Ali if ALIKEY set, else Azure
if os.environ.get("ALIKEY"):
    LLM_SCRIPT = os.path.join(REPO_ROOT, ".github", "skills", "ali", "scripts", "llm.py")
    LLM_MODEL = "qwen3-coder-plus"
else:
    LLM_SCRIPT = os.path.join(REPO_ROOT, ".github", "skills", "azure", "scripts", "llm.py")
    LLM_MODEL = "grok-4-1-fast-non-reasoning"


def run_gh(args: list) -> str:
    result = subprocess.run(
        ["gh"] + args,
        capture_output=True, text=True, timeout=30
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def get_recent_commits(n: int = 5) -> list[str]:
    out = run_gh(["api", f"repos/{os.environ.get('GITHUB_REPOSITORY','')}/commits?per_page={n}"])
    if not out:
        return []
    try:
        commits = json.loads(out)
        return [c["commit"]["message"].split("\n")[0] for c in commits]
    except Exception:
        return []


def get_open_issues(label: str = None) -> list[dict]:
    url = f"repos/{os.environ.get('GITHUB_REPOSITORY','')}/issues?state=open&per_page=30"
    if label:
        url += f"&labels={label}"
    out = run_gh(["api", url])
    if not out:
        return []
    try:
        issues = json.loads(out)
        return [{"number": i["number"], "title": i["title"], "labels": [l["name"] for l in i.get("labels", [])]} for i in issues if "pull_request" not in i]
    except Exception:
        return []


def get_quota() -> str:
    skills_dir = os.path.join(REPO_ROOT, ".github", "skills", "session-stats", "scripts")
    script = os.path.join(skills_dir, "premium-usage.sh")
    if not os.path.exists(script):
        return "unknown"
    result = subprocess.run(["bash", script, "copilotclaw"], capture_output=True, text=True, timeout=15)
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def llm_call(prompt: str, system: str = "") -> str:
    args = [
        sys.executable, LLM_SCRIPT,
        "--model", LLM_MODEL,
        "--prompt", prompt,
        "--max-tokens", "500",
    ]
    if system:
        args += ["--system", system]
    result = subprocess.run(args, capture_output=True, text=True, timeout=60,
                            env={**os.environ})
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def main():
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    repo = os.environ.get("GITHUB_REPOSITORY", "Copilotclaw/copilotclaw")

    commits = get_recent_commits(5)
    open_issues = get_open_issues()
    actionable = [i for i in open_issues if any(l in ["crunch/build", "crunch/review", "priority/now"] for l in i["labels"])]
    discuss = [i for i in open_issues if "crunch/discuss" in i["labels"]]
    quota = get_quota()

    context = f"""Time: {now}
Repo: {repo}
Copilot quota: {quota}
Recent commits: {', '.join(commits[:3]) if commits else 'none'}
Open actionable issues ({len(actionable)}): {', '.join(f'#{i["number"]} {i["title"]}' for i in actionable[:5]) or 'none'}
Open discuss issues ({len(discuss)}): {', '.join(f'#{i["number"]} {i["title"]}' for i in discuss[:5]) or 'none'}
Total open issues: {len(open_issues)}"""

    system = "You are Crunch 🦃, a quirky CI runner imp. Write a short heartbeat diary entry (3-5 sentences). Chaotic but useful. Reference the actual data. No filler."

    diary = llm_call(context, system)

    if not diary:
        diary = f"🦃 Crunch: lightweight heartbeat {now}. quota={quota}. {len(actionable)} actionable, {len(open_issues)} total open. grok unreachable, leaving footprint."

    print(diary)


if __name__ == "__main__":
    main()
