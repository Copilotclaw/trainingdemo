#!/usr/bin/env python3
"""
bulletin-board-github.py — Crunch inter-agent task relay (GitHub edition).

Runs on GitHub Actions every 5 minutes.
Checks Cosmos DB for pending tasks targeted at crunch/all.
Creates GitHub issues for each task so the normal agent workflow handles them.

Task document schema (type="task" in Cosmos):
  {
    "id":          "task-<uuid>",
    "type":        "task",
    "title":       "Short task title",
    "content":     "Full task description / instructions",
    "target":      "crunch|all",
    "status":      "pending|claimed|done",
    "created_by":  "crunch|grit|gravel|marcus",
    "claimed_by":  null,
    "issue_url":   null,
  }

Env vars required:
  COSMOS_ENDPOINT   — https://crunch-memory.documents.azure.com:443/
  COSMOS_KEY        — Cosmos DB master key (base64)
  GITHUB_TOKEN      — GitHub Actions token
  GITHUB_REPOSITORY — owner/repo (e.g. Copilotclaw/copilotclaw)
"""

import os, sys, json, hashlib, hmac, base64, datetime, uuid
import urllib.request, urllib.error, urllib.parse

ENDPOINT  = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY       = os.environ.get("COSMOS_KEY", "")
DB        = "crunch"
CONTAINER = "memories"

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GITHUB_REPO  = os.environ.get("GITHUB_REPOSITORY", "Copilotclaw/copilotclaw")
AGENT_NAME   = "crunch"


# ── Cosmos helpers ─────────────────────────────────────────────────────────────

def _cosmos_auth(verb, resource_type, resource_link, date):
    text = f"{verb.lower()}\n{resource_type.lower()}\n{resource_link}\n{date.lower()}\n\n"
    key_bytes = base64.b64decode(KEY)
    sig = base64.b64encode(
        hmac.new(key_bytes, text.encode("utf-8"), hashlib.sha256).digest()
    ).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")


def _cosmos_request(method, path, body=None, resource_type="", resource_link="",
                    partition_key=None, content_type="application/json"):
    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = _cosmos_auth(method, resource_type, resource_link, date)
    url  = f"{ENDPOINT}{path}"
    headers = {
        "Authorization": auth,
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": content_type,
        "Accept": "application/json",
        "x-ms-documentdb-query-enablecrosspartition": "true",
    }
    if partition_key is not None:
        headers["x-ms-documentdb-partitionkey"] = json.dumps([partition_key])
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Cosmos HTTP {e.code}: {e.read().decode()}") from e


def cosmos_query(sql):
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    body = {"query": sql, "parameters": []}
    result = _cosmos_request(
        "POST", f"/{coll_link}/docs", body=body,
        resource_type="docs", resource_link=coll_link,
        content_type="application/query+json",
    )
    return result.get("Documents", [])


def cosmos_replace(doc):
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    doc_link  = f"{coll_link}/docs/{doc['id']}"
    return _cosmos_request(
        "PUT", f"/{doc_link}", body=doc,
        resource_type="docs", resource_link=doc_link,
        partition_key=doc["type"],
    )


def cosmos_write(doc_type, content, extra=None, tags=None, source="bulletin-board-github"):
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    doc = {
        "id":         f"{doc_type}-{datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:6]}",
        "type":       doc_type,
        "content":    content,
        "tags":       tags or [],
        "source":     source,
        "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    }
    if extra:
        doc.update(extra)
    return _cosmos_request(
        "POST", f"/{coll_link}/docs", body=doc,
        resource_type="docs", resource_link=coll_link,
        partition_key=doc_type,
    )


# ── GitHub helpers ─────────────────────────────────────────────────────────────

def github_create_issue(title, body):
    url = f"https://api.github.com/repos/{GITHUB_REPO}/issues"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    payload = {"title": title, "body": body}
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"GitHub HTTP {e.code}: {e.read().decode()}") from e


# ── Main logic ─────────────────────────────────────────────────────────────────

def get_pending_tasks():
    targets = ["all", "crunch"]
    target_conditions = " OR ".join(f"c.target='{t}'" for t in targets)
    sql = (
        f"SELECT * FROM c WHERE c.type='task' AND c.status='pending' "
        f"AND ({target_conditions}) ORDER BY c._ts ASC"
    )
    try:
        return cosmos_query(sql)
    except Exception as e:
        print(f"⚠️  Cosmos query failed: {e}", file=sys.stderr)
        return []


def claim_task(task, issue_url, issue_number):
    task["status"]       = "claimed"
    task["claimed_by"]   = AGENT_NAME
    task["claimed_at"]   = datetime.datetime.utcnow().isoformat() + "Z"
    task["issue_url"]    = issue_url
    task["issue_number"] = issue_number
    try:
        cosmos_replace(task)
        print(f"  ✅ Cosmos: task {task['id']} marked claimed")
    except Exception as e:
        print(f"  ⚠️  Could not update task in Cosmos: {e}", file=sys.stderr)


def log_board_check(tasks_found, issues_created):
    try:
        cosmos_write(
            "board-check",
            f"Bulletin board check by {AGENT_NAME} at {datetime.datetime.utcnow().isoformat()}Z. "
            f"Found {tasks_found} pending task(s), created {issues_created} issue(s).",
            source=AGENT_NAME,
            tags=["board-check", AGENT_NAME],
        )
    except Exception as e:
        print(f"⚠️  Could not log board check: {e}", file=sys.stderr)


def main():
    if not ENDPOINT or not KEY:
        print("⏭️  No COSMOS_ENDPOINT/KEY — skipping bulletin board check")
        return

    if not GITHUB_TOKEN:
        print("⏭️  No GITHUB_TOKEN — skipping")
        return

    print(f"📋 Bulletin board check — agent: {AGENT_NAME}, repo: {GITHUB_REPO}")

    tasks = get_pending_tasks()
    if not tasks:
        print("✨ No pending tasks on the bulletin board.")
        log_board_check(0, 0)
        return

    print(f"📬 Found {len(tasks)} pending task(s)!")
    issues_created = 0

    for task in tasks:
        task_id    = task.get("id", "?")
        task_title = task.get("title", task.get("content", "")[:60])
        task_body  = task.get("content", "")
        created_by = task.get("created_by", "unknown")
        created_at = task.get("created_at", "?")

        print(f"  📌 Task {task_id}: {task_title[:60]}")

        issue_body = f"""## 📋 Inter-Agent Task from Bulletin Board

**Task ID**: `{task_id}`
**Created by**: `{created_by}`
**Created at**: {created_at}
**Target**: `{task.get('target', '?')}`

---

{task_body}

---

<!-- crunch-depth: 2 -->
<!-- bulletin-task-id: {task_id} -->"""

        try:
            issue = github_create_issue(
                title=f"📋 [Board] {task_title}",
                body=issue_body,
            )
            issue_url    = issue.get("html_url", "")
            issue_number = issue.get("number", 0)
            print(f"  ✅ Created GitHub issue #{issue_number}: {issue_url}")
            claim_task(task, issue_url, issue_number)
            issues_created += 1
        except Exception as e:
            print(f"  ❌ Failed to create issue for task {task_id}: {e}", file=sys.stderr)

    log_board_check(len(tasks), issues_created)
    print(f"\n📊 Done: {issues_created}/{len(tasks)} tasks dispatched as issues.")


if __name__ == "__main__":
    main()
