#!/usr/bin/env python3
"""
platform.py — Platform detection and unified API client.

Detects GitHub Actions vs Gitea Actions vs local.
Provides a minimal HTTP client for common operations.

Import this in other scripts:
    from platform import get_platform, api_get, api_post, api_patch
"""

import os
import sys
import json
import urllib.request
import urllib.error
from typing import Any, Optional


def get_platform() -> dict:
    """Detect current platform and return auth/URL context."""

    # Gitea Actions: GITEA_ACTIONS is set (or check server URL format)
    if os.getenv("GITEA_ACTIONS") or os.getenv("GITEA_TOKEN"):
        server = os.getenv("GITHUB_SERVER_URL") or os.getenv("GITEA_SERVER_URL", "")
        # Prefer LOCAL_PAT (full-access Gitea PAT) over repo-scoped github.token
        token = os.getenv("LOCAL_PAT") or os.getenv("GITEA_TOKEN") or os.getenv("GITHUB_TOKEN", "")
        repo = os.getenv("GITHUB_REPOSITORY", "")
        return {
            "type": "gitea",
            "server": server.rstrip("/"),
            "api_base": f"{server.rstrip('/')}/api/v1",
            "token": token,
            "repo": repo,
        }

    # GitHub Actions: GITHUB_ACTIONS is set
    if os.getenv("GITHUB_ACTIONS"):
        server = os.getenv("GITHUB_SERVER_URL", "https://github.com")
        token = os.getenv("GH_TOKEN") or os.getenv("GITHUB_TOKEN", "")
        repo = os.getenv("GITHUB_REPOSITORY", "")
        return {
            "type": "github",
            "server": server.rstrip("/"),
            "api_base": "https://api.github.com",
            "token": token,
            "repo": repo,
        }

    # Local: read from env or gh CLI
    token = os.getenv("GH_TOKEN") or os.getenv("GITHUB_TOKEN") or _gh_token_from_cli()
    repo = os.getenv("GITHUB_REPOSITORY") or _repo_from_git_remote()
    return {
        "type": "local",
        "server": "https://github.com",
        "api_base": "https://api.github.com",
        "token": token,
        "repo": repo,
    }


def _gh_token_from_cli() -> str:
    """Try to get token from gh CLI (local dev)."""
    try:
        import subprocess
        result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=5)
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""


def _repo_from_git_remote() -> str:
    """Try to extract owner/repo from git remote."""
    try:
        import subprocess
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5
        )
        url = result.stdout.strip()
        # Handle both https://github.com/owner/repo.git and git@github.com:owner/repo.git
        if "github.com" in url:
            url = url.rstrip(".git")
            if ":" in url.split("github.com")[-1]:  # SSH
                return url.split(":")[-1]
            else:
                return "/".join(url.split("/")[-2:])
    except Exception:
        pass
    return ""


def _request(method: str, url: str, token: str, data: Optional[dict] = None) -> dict:
    """Make an HTTP request. Returns parsed JSON or raises."""
    headers = {
        "Authorization": f"token {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()
        raise RuntimeError(f"HTTP {e.code} {method} {url}: {body_text}") from e


def api_get(ctx: dict, path: str) -> dict:
    """GET {api_base}/{path}"""
    url = f"{ctx['api_base']}/{path.lstrip('/')}"
    return _request("GET", url, ctx["token"])


def api_post(ctx: dict, path: str, data: dict) -> dict:
    """POST {api_base}/{path} with JSON data."""
    url = f"{ctx['api_base']}/{path.lstrip('/')}"
    return _request("POST", url, ctx["token"], data)


def api_patch(ctx: dict, path: str, data: dict) -> dict:
    """PATCH {api_base}/{path} with JSON data."""
    url = f"{ctx['api_base']}/{path.lstrip('/')}"
    return _request("PATCH", url, ctx["token"], data)


if __name__ == "__main__":
    ctx = get_platform()
    print(f"Platform: {ctx['type']}")
    print(f"Repo:     {ctx['repo']}")
    print(f"API:      {ctx['api_base']}")
    print(f"Token:    {'set' if ctx['token'] else 'MISSING'}")
