#!/usr/bin/env python3
"""
issue_create.py — Create an issue on GitHub or Gitea.

Usage:
    python issue_create.py <title> <body> [label1,label2]
    python issue_create.py "Bug found" "Description here" "bug,crunch/ready"

Environment:
    Auto-detected (GitHub Actions / Gitea Actions / local).
    Override repo: GITHUB_REPOSITORY=owner/repo
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from platform import get_platform, api_post


def create_issue(title: str, body: str, labels: list[str] = None) -> dict:
    ctx = get_platform()
    repo = ctx["repo"]

    payload = {"title": title, "body": body}
    if labels:
        payload["labels"] = labels

    path = f"repos/{repo}/issues"
    return api_post(ctx, path, payload)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <title> <body> [label1,label2]", file=sys.stderr)
        sys.exit(1)

    title = sys.argv[1]
    body = sys.argv[2]
    labels = sys.argv[3].split(",") if len(sys.argv) > 3 else []

    result = create_issue(title, body, labels)
    num = result.get("number")
    url = result.get("html_url") or result.get("url", "?")
    print(f"✅ Issue #{num} created: {url}")
