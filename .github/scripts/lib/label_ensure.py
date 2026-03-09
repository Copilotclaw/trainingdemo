#!/usr/bin/env python3
"""
label_ensure.py — Ensure a label exists on GitHub or Gitea. Create if missing.

Usage:
    python label_ensure.py <name> [color] [description]
    python label_ensure.py "spark/ready" "0075ca" "Ready for Spark agent"

Defaults to color "ededed" if not provided.

Environment:
    Auto-detected (GitHub Actions / Gitea Actions / local).
    Override repo: GITHUB_REPOSITORY=owner/repo
"""

import sys
import os
import json

sys.path.insert(0, os.path.dirname(__file__))
from platform import get_platform, api_get, api_post


def ensure_label(name: str, color: str = "ededed", description: str = "") -> str:
    ctx = get_platform()
    repo = ctx["repo"]

    # Check if label exists
    try:
        existing = api_get(ctx, f"repos/{repo}/labels")
        for label in existing:
            if label.get("name") == name:
                return "exists"
    except Exception:
        pass

    # Create it
    payload = {"name": name, "color": color.lstrip("#")}
    if description:
        payload["description"] = description

    api_post(ctx, f"repos/{repo}/labels", payload)
    return "created"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <name> [color] [description]", file=sys.stderr)
        sys.exit(1)

    name = sys.argv[1]
    color = sys.argv[2] if len(sys.argv) > 2 else "ededed"
    description = sys.argv[3] if len(sys.argv) > 3 else ""

    status = ensure_label(name, color, description)
    print(f"✅ Label '{name}': {status}")
