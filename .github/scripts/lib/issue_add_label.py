#!/usr/bin/env python3
"""
issue_add_label.py — Add a label to an issue on GitHub or Gitea.

Usage:
    python issue_add_label.py <issue_number> <label_name>

GitHub: accepts label names directly.
Gitea:  looks up the label ID, then applies it.

Environment:
    Auto-detected (GitHub Actions / Gitea Actions / local).
    Override repo: GITHUB_REPOSITORY=owner/repo
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from platform import get_platform, api_get, api_post


def add_label(issue_number: int, label_name: str) -> dict:
    ctx = get_platform()
    repo = ctx["repo"]

    if ctx["type"] == "gitea":
        # Gitea requires label IDs
        all_labels = api_get(ctx, f"repos/{repo}/labels?limit=100")
        label = next((l for l in all_labels if l.get("name") == label_name), None)
        if not label:
            raise ValueError(f"Label '{label_name}' not found in {repo}")
        return api_post(ctx, f"repos/{repo}/issues/{issue_number}/labels",
                        {"labels": [label["id"]]})
    else:
        # GitHub accepts label names
        return api_post(ctx, f"repos/{repo}/issues/{issue_number}/labels",
                        {"labels": [label_name]})


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <issue_number> <label_name>", file=sys.stderr)
        sys.exit(1)

    num = int(sys.argv[1])
    name = sys.argv[2]

    try:
        add_label(num, name)
        print(f"✅ Label '{name}' added to issue #{num}")
    except Exception as e:
        print(f"❌ {e}", file=sys.stderr)
        sys.exit(1)
