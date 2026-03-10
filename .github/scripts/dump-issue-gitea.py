#!/usr/bin/env python3
"""
dump-issue-gitea.py — Dump a Gitea issue thread to a full markdown file.

Usage:
    python3 dump-issue-gitea.py <issue_number> [output_file]

Environment:
    GITEA_TOKEN   - Gitea API token
    GITEA_SERVER  - Gitea server URL (e.g. http://localhost:3000)
    GITEA_REPO    - Gitea repo (e.g. mac/copilotclaw)
"""
import json
import os
import sys
import urllib.request
import urllib.error


def gitea_get(server, token, path):
    url = f"{server}/api/v1{path}"
    req = urllib.request.Request(url, headers={"Authorization": f"token {token}"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def main():
    if len(sys.argv) < 2:
        print("Usage: dump-issue-gitea.py <issue_number> [output_file]", file=sys.stderr)
        sys.exit(1)

    issue_number = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 else f"state/issues/{issue_number}.full.md"

    token = os.environ["GITEA_TOKEN"]
    server = os.environ["GITEA_SERVER"].rstrip("/")
    repo = os.environ["GITEA_REPO"]

    issue = gitea_get(server, token, f"/repos/{repo}/issues/{issue_number}")
    comments = gitea_get(server, token, f"/repos/{repo}/issues/{issue_number}/comments?limit=50")

    labels = ", ".join(l["name"] for l in issue.get("labels", [])) or "none"

    lines = [
        f"# Issue #{issue['number']}: {issue['title']}",
        "",
        f"**URL**: {issue.get('html_url', f'{server}/{repo}/issues/{issue_number}')}",
        f"**State**: {issue['state']}",
        f"**Author**: {issue['user']['login']}",
        f"**Created**: {issue['created_at']}",
        f"**Updated**: {issue['updated_at']}",
        f"**Labels**: {labels}",
        "",
        "---",
        "",
        "## Original Post",
        "",
        issue.get("body") or "_(empty)_",
        "",
        "---",
        "",
        f"## Comments ({len(comments)})",
        "",
    ]

    for i, c in enumerate(comments, 1):
        lines.append(f"### Comment {i} — {c['user']['login']} ({c['created_at']})")
        lines.append("")
        lines.append(c.get("body") or "_(empty)_")
        lines.append("")

    os.makedirs(os.path.dirname(output) or ".", exist_ok=True)
    with open(output, "w") as f:
        f.write("\n".join(lines))

    line_count = lines.__len__()
    print(f"✅ Wrote {line_count} lines to {output}")


if __name__ == "__main__":
    main()
