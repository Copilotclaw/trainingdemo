#!/usr/bin/env python3
"""
bulletin-board-check.py — Crunch inter-agent task relay.

Runs on Gitea agents (Grit, Gravel) every 5 minutes.
Checks Cosmos DB for pending tasks targeted at this instance.
Creates Gitea issues for each task so the normal agent workflow handles them.

Task document schema (type="task" in Cosmos):
  {
    "id":          "task-<uuid>",
    "type":        "task",                          # partition key
    "title":       "Short task title",
    "content":     "Full task description / instructions",
    "target":      "grit|gravel|local|crunch|all",  # "local" = any Gitea agent
    "status":      "pending|claimed|done",
    "created_by":  "crunch|grit|gravel|marcus",
    "claimed_by":  null,
    "issue_url":   null,
    "tags":        [],
    "created_at":  "ISO 8601"
  }

Env vars required:
  COSMOS_ENDPOINT   — https://crunch-memory.documents.azure.com:443/
  COSMOS_KEY        — Cosmos DB master key (base64)
  GITEA_TOKEN       — Gitea Actions token (github.token)
  GITEA_SERVER      — Gitea server URL (e.g. http://localhost:3000)
  GITEA_REPO        — owner/repo (e.g. mac/copilotclaw)

Optional:
  AGENT_NAME        — Name of this agent instance (default: grit)
"""

import os, sys, json, hashlib, hmac, base64, datetime, uuid
import urllib.request, urllib.error, urllib.parse

ENDPOINT  = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY       = os.environ.get("COSMOS_KEY", "")
DB        = "crunch"
CONTAINER = "memories"

GITEA_TOKEN  = os.environ.get("GITEA_TOKEN", "")
GITEA_SERVER = os.environ.get("GITEA_SERVER", "").rstrip("/")
GITEA_REPO   = os.environ.get("GITEA_REPO", "")
AGENT_NAME   = os.environ.get("AGENT_NAME", "grit").lower()

# Labels to apply to created issues so the agent workflow picks them up
ISSUE_LABELS = ["crunch/build", "priority/now"]


# ── Cosmos helpers ────────────────────────────────────────────────────────────

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
    """Run a cross-partition SQL query, return list of docs."""
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    body = {"query": sql, "parameters": []}
    result = _cosmos_request(
        "POST", f"/{coll_link}/docs", body=body,
        resource_type="docs", resource_link=coll_link,
        content_type="application/query+json",
    )
    return result.get("Documents", [])


def cosmos_replace(doc):
    """Replace (update) an existing document. doc must include 'id' and 'type'."""
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    doc_link  = f"{coll_link}/docs/{doc['id']}"
    return _cosmos_request(
        "PUT", f"/{doc_link}", body=doc,
        resource_type="docs", resource_link=doc_link,
        partition_key=doc["type"],
    )


def cosmos_write(doc_type, content, extra=None, tags=None, source="bulletin-board"):
    """Write a new document."""
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


# ── Gitea helpers ─────────────────────────────────────────────────────────────

def gitea_request(method, path, body=None):
    url  = f"{GITEA_SERVER}/api/v1{path}"
    headers = {
        "Authorization": f"token {GITEA_TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Gitea HTTP {e.code}: {e.read().decode()}") from e


def gitea_create_issue(title, body, labels=None):
    """Create a Gitea issue. Returns the created issue dict."""
    payload = {"title": title, "body": body}
    if labels:
        # Gitea accepts label IDs or strings depending on version — try names first
        label_ids = []
        for lname in labels:
            try:
                result = gitea_request("GET", f"/repos/{GITEA_REPO}/labels?limit=50")
                for lbl in result:
                    if lbl.get("name") == lname:
                        label_ids.append(lbl["id"])
                        break
            except Exception:
                pass
        if label_ids:
            payload["labels"] = label_ids
    return gitea_request("POST", f"/repos/{GITEA_REPO}/issues", payload)


# ── Main logic ────────────────────────────────────────────────────────────────

def get_pending_tasks():
    """Query Cosmos for tasks targeting this agent (or all/local)."""
    targets = ["all", "local", AGENT_NAME]
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
    """Mark task as claimed in Cosmos."""
    task["status"]     = "claimed"
    task["claimed_by"] = AGENT_NAME
    task["claimed_at"] = datetime.datetime.utcnow().isoformat() + "Z"
    task["issue_url"]  = issue_url
    task["issue_number"] = issue_number
    try:
        cosmos_replace(task)
        print(f"  ✅ Cosmos: task {task['id']} marked claimed")
    except Exception as e:
        print(f"  ⚠️  Could not update task in Cosmos: {e}", file=sys.stderr)


def log_board_check(tasks_found, issues_created):
    """Write a brief board-check event to Cosmos for audit trail."""
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

    if not GITEA_TOKEN or not GITEA_SERVER or not GITEA_REPO:
        print("⏭️  No Gitea credentials — skipping bulletin board check")
        return

    print(f"📋 Bulletin board check — agent: {AGENT_NAME}, repo: {GITEA_REPO}")

    tasks = get_pending_tasks()
    if not tasks:
        print("✨ No pending tasks on the bulletin board.")
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

        # Build issue body
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
            issue = gitea_create_issue(
                title=f"📋 [Board] {task_title}",
                body=issue_body,
                labels=ISSUE_LABELS,
            )
            issue_url    = issue.get("html_url", issue.get("url", ""))
            issue_number = issue.get("number", 0)
            print(f"  ✅ Created Gitea issue #{issue_number}: {issue_url}")
            claim_task(task, issue_url, issue_number)
            issues_created += 1
        except Exception as e:
            print(f"  ❌ Failed to create issue for task {task_id}: {e}", file=sys.stderr)

    log_board_check(len(tasks), issues_created)
    print(f"\n📊 Done: {issues_created}/{len(tasks)} tasks dispatched as issues.")


if __name__ == "__main__":
    main()
