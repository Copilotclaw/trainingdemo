#!/usr/bin/env python3
"""
issue_list.py — List open issues on GitHub or Gitea.

Usage:
    python issue_list.py [label]
    python issue_list.py spark/ready

Output: JSON array of issues to stdout.

Environment:
    Auto-detected (GitHub Actions / Gitea Actions / local).
    Override repo: GITHUB_REPOSITORY=owner/repo
"""

import sys
import os
import json

sys.path.insert(0, os.path.dirname(__file__))
from platform import get_platform, api_get


def list_issues(label: str = None, state: str = "open") -> list:
    ctx = get_platform()
    repo = ctx["repo"]

    params = f"state={state}&per_page=50"
    if label:
        params += f"&labels={label}"

    path = f"repos/{repo}/issues?{params}"
    result = api_get(ctx, path)

    # GitHub returns pull requests mixed in — filter them out
    if ctx["type"] == "github":
        result = [i for i in result if "pull_request" not in i]

    return result


if __name__ == "__main__":
    label = sys.argv[1] if len(sys.argv) > 1 else None
    issues = list_issues(label)

    # Compact output — title + number + url per line
    for issue in issues:
        num = issue.get("number")
        title = issue.get("title", "")
        url = issue.get("html_url") or issue.get("url", "")
        print(f"#{num}: {title} — {url}")

    if not issues:
        print("(no issues found)")
