#!/bin/bash
# followup.sh — Cosmos DB followup system for Crunch agents
#
# A "followup" is a deferred check: someone is waiting for something (feedback,
# a PR to land, a decision) and wants to be reminded to check back.
#
# Cosmos document shape:
#   type:         "followup"  (partition key)
#   issue_number: int | null
#   comment_ref:  url | null
#   check_date:   ISO 8601 — when to re-check
#   agent:        "crunch" | "grit" | "gravel" | "all"
#   notes:        free text — what we're waiting for
#   status:       "open" | "closed"
#
# Usage:
#   followup.sh write --notes "Waiting for X" [--issue N] [--agent crunch] [--check-date 2026-03-14] [--comment-ref URL]
#   followup.sh list [--agent crunch] [--status open]
#   followup.sh close <followup-id>
#   followup.sh check [--agent crunch]   — surface overdue followups (for heartbeat)
#   followup.sh overdue [--agent crunch] — print overdue count (exit 1 if any)
set -euo pipefail

CMD="${1:-list}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COSMOS_SCRIPT="$SCRIPT_DIR/cosmos-memory.py"

_require_cosmos() {
  if [[ -z "${COSMOS_ENDPOINT:-}" || -z "${COSMOS_KEY:-}" ]]; then
    echo "❌ COSMOS_ENDPOINT and COSMOS_KEY env vars required" >&2
    exit 1
  fi
}

_cosmos_py() {
  python3 - "$@" <<'PYEOF'
import os, sys, json, hashlib, hmac, base64, datetime, uuid, argparse
import urllib.request, urllib.error, urllib.parse

ENDPOINT  = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY       = os.environ.get("COSMOS_KEY", "")
DB        = "crunch"
CONTAINER = "memories"

def auth(verb, rtype, rlink, date):
    text = f"{verb.lower()}\n{rtype.lower()}\n{rlink}\n{date.lower()}\n\n"
    sig = base64.b64encode(hmac.new(base64.b64decode(KEY), text.encode(), hashlib.sha256).digest()).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")

def req(method, path, body=None, rtype="", rlink="", pk=None, ct="application/json"):
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
    hdrs = {
        "Authorization": auth(method, rtype, rlink, date),
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": ct,
        "Accept": "application/json",
    }
    if pk is not None:
        hdrs["x-ms-documentdb-partitionkey"] = json.dumps([pk])
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(f"{ENDPOINT}{path}", data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        raise RuntimeError(f"HTTP {e.code}: {err}") from e

def query(sql):
    clink = f"dbs/{DB}/colls/{CONTAINER}"
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
    hdrs = {
        "Authorization": auth("POST", "docs", clink, date),
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": "application/query+json",
        "Accept": "application/json",
        "x-ms-documentdb-isquery": "true",
        "x-ms-max-item-count": "100",
        "x-ms-documentdb-query-enablecrosspartition": "true",
    }
    body = json.dumps({"query": sql, "parameters": []}).encode()
    r = urllib.request.Request(f"{ENDPOINT}/{clink}/docs", data=body, headers=hdrs, method="POST")
    with urllib.request.urlopen(r) as resp:
        return json.loads(resp.read()).get("Documents", [])

def write_followup(notes, issue_number=None, comment_ref=None, agent="crunch",
                   check_date=None, source="agent"):
    now = datetime.datetime.now(datetime.timezone.utc)
    if check_date is None:
        check_date = (now + datetime.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ")
    doc_id = f"followup-{now.strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:6]}"
    doc = {
        "id":           doc_id,
        "type":         "followup",
        "content":      notes,
        "notes":        notes,
        "issue_number": issue_number,
        "comment_ref":  comment_ref,
        "check_date":   check_date,
        "agent":        agent,
        "status":       "open",
        "tags":         ["followup", agent],
        "source":       source,
        "created_at":   now.isoformat(),
    }
    clink = f"dbs/{DB}/colls/{CONTAINER}"
    result = req("POST", f"/{clink}/docs", body=doc, rtype="docs",
                 rlink=clink, pk="followup")
    return result

def close_followup(doc_id):
    clink = f"dbs/{DB}/colls/{CONTAINER}"
    dlink = f"{clink}/docs/{doc_id}"
    doc = req("GET", f"/{dlink}", rtype="docs", rlink=dlink, pk="followup")
    doc["status"] = "closed"
    doc["closed_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    req("PUT", f"/{dlink}", body=doc, rtype="docs", rlink=dlink, pk="followup")
    return doc

def fmt_followup(d):
    status = d.get("status", "?")
    icon = "🔔" if status == "open" else "✅"
    issue = f"#{d['issue_number']}" if d.get("issue_number") else "-"
    agent = d.get("agent", "?")
    check = d.get("check_date", "?")[:10]
    notes = d.get("notes", d.get("content", ""))[:80]
    return f"{icon} [{d['id']}] agent={agent} issue={issue} check={check} | {notes}"

p = argparse.ArgumentParser()
sub = p.add_subparsers(dest="cmd")

wp = sub.add_parser("write")
wp.add_argument("--notes", required=True)
wp.add_argument("--issue", type=int, default=None)
wp.add_argument("--comment-ref", default=None)
wp.add_argument("--agent", default="crunch")
wp.add_argument("--check-date", default=None)
wp.add_argument("--source", default="agent")

lp = sub.add_parser("list")
lp.add_argument("--agent", default=None)
lp.add_argument("--status", default="open")
lp.add_argument("--limit", type=int, default=20)

cp = sub.add_parser("close")
cp.add_argument("doc_id")

chk = sub.add_parser("check")
chk.add_argument("--agent", default=None)

ov = sub.add_parser("overdue")
ov.add_argument("--agent", default=None)

args = p.parse_args()

if args.cmd == "write":
    doc = write_followup(
        notes=args.notes,
        issue_number=args.issue,
        comment_ref=getattr(args, "comment_ref", None),
        agent=args.agent,
        check_date=getattr(args, "check_date", None),
        source=args.source,
    )
    print(f"✅ Followup created: {doc['id']}")
    print(f"   agent={doc['agent']} check_date={doc['check_date']}")

elif args.cmd == "list":
    agent_filter = f" AND c.agent='{args.agent}'" if args.agent else ""
    status_filter = f" AND c.status='{args.status}'" if args.status else ""
    sql = f"SELECT TOP {args.limit} * FROM c WHERE c.type='followup'{agent_filter}{status_filter} ORDER BY c._ts DESC"
    docs = query(sql)
    if not docs:
        print("ℹ️ No followups found")
    else:
        for d in docs:
            print(fmt_followup(d))

elif args.cmd == "close":
    doc = close_followup(args.doc_id)
    print(f"✅ Closed: {args.doc_id}")

elif args.cmd in ("check", "overdue"):
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    agent_filter = f" AND c.agent='{args.agent}'" if args.agent else ""
    sql = (f"SELECT TOP 50 * FROM c WHERE c.type='followup'"
           f" AND c.status='open'"
           f" AND c.check_date <= '{now_iso}'"
           f"{agent_filter}"
           f" ORDER BY c.check_date ASC")
    docs = query(sql)
    if args.cmd == "overdue":
        sys.exit(0 if not docs else 1)
    if not docs:
        print("✅ No overdue followups")
    else:
        print(f"⚠️ {len(docs)} overdue followup(s):")
        for d in docs:
            print(fmt_followup(d))

else:
    p.print_help()
    sys.exit(1)
PYEOF
}

case "$CMD" in
  write)
    _require_cosmos
    shift
    _cosmos_py write "$@"
    ;;

  list)
    _require_cosmos
    shift
    _cosmos_py list "$@"
    ;;

  close)
    _require_cosmos
    DOC_ID="${2:-}"
    if [[ -z "$DOC_ID" ]]; then
      echo "Usage: followup.sh close <followup-id>" >&2
      exit 1
    fi
    _cosmos_py close "$DOC_ID"
    ;;

  check)
    _require_cosmos
    shift
    _cosmos_py check "$@"
    ;;

  overdue)
    _require_cosmos
    shift
    _cosmos_py overdue "$@"
    ;;

  *)
    echo "Usage: followup.sh [write|list|close|check|overdue]"
    echo ""
    echo "  write   --notes TEXT [--issue N] [--agent crunch] [--check-date YYYY-MM-DD] [--comment-ref URL]"
    echo "  list    [--agent crunch] [--status open|closed] [--limit N]"
    echo "  close   <followup-id>"
    echo "  check   [--agent crunch]   — surface overdue followups"
    echo "  overdue [--agent crunch]   — exit 1 if any overdue"
    exit 1
    ;;
esac
