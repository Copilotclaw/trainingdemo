#!/usr/bin/env python3
"""
issue_comment.py — Add a comment to a GitHub or Gitea issue.

Usage:
    python issue_comment.py <issue_number> <body>
    python issue_comment.py 42 "Hello from Crunch 🦃"

Environment:
    Auto-detected (GitHub Actions / Gitea Actions / local).
    Override repo: GITHUB_REPOSITORY=owner/repo
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from platform import get_platform, api_post


def comment_on_issue(issue_number: int, body: str) -> dict:
    ctx = get_platform()
    repo = ctx["repo"]

    if ctx["type"] == "gitea":
        path = f"repos/{repo}/issues/{issue_number}/comments"
    else:
        path = f"repos/{repo}/issues/{issue_number}/comments"

    return api_post(ctx, path, {"body": body})


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <issue_number> <body>", file=sys.stderr)
        sys.exit(1)

    issue_num = int(sys.argv[1])
    body = sys.argv[2]

    result = comment_on_issue(issue_num, body)
    print(f"✅ Comment posted: {result.get('html_url') or result.get('url', 'ok')}")
