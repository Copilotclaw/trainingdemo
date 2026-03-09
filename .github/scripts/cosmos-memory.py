#!/usr/bin/env python3
"""
cosmos-memory.py — Crunch's persistent brain. Read/write to Azure Cosmos DB.

Requires env vars:
  COSMOS_ENDPOINT — https://crunch-memory.documents.azure.com:443/
  COSMOS_KEY      — primary master key (base64)

Container schema:
  DB: crunch  |  Container: memories  |  Partition key: /type

Document shape:
  {
    "id":         "<unique string>",
    "type":       "<diary|memory|fact|session>",  # partition key
    "content":    "<text>",
    "tags":       ["optional", "tags"],
    "source":     "<heartbeat|agent|manual>",
    "created_at": "<ISO 8601>"
  }

Usage:
  python3 cosmos-memory.py write  --type diary --content "..." [--tags t1,t2] [--source heartbeat]
  python3 cosmos-memory.py read   --id <doc-id> --type <partition>
  python3 cosmos-memory.py query  --sql "SELECT TOP 10 * FROM c WHERE c.type='diary' ORDER BY c._ts DESC"
  python3 cosmos-memory.py recent [--type diary] [--limit 5]
"""

import os, sys, json, hashlib, hmac, base64, datetime, uuid, argparse
import urllib.request, urllib.error, urllib.parse

ENDPOINT  = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY       = os.environ.get("COSMOS_KEY", "")
DB        = "crunch"
CONTAINER = "memories"


def _require_creds():
    if not ENDPOINT or not KEY:
        print("❌ COSMOS_ENDPOINT and COSMOS_KEY env vars required", file=sys.stderr)
        sys.exit(1)


def _auth(verb: str, resource_type: str, resource_link: str, date: str) -> str:
    text = f"{verb.lower()}\n{resource_type.lower()}\n{resource_link}\n{date.lower()}\n\n"
    key_bytes = base64.b64decode(KEY)
    sig = base64.b64encode(
        hmac.new(key_bytes, text.encode("utf-8"), hashlib.sha256).digest()
    ).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")


def _request(method: str, path: str, body=None, resource_type: str = "",
             resource_link: str = "", partition_key: str = None):
    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = _auth(method, resource_type, resource_link, date)
    url  = f"{ENDPOINT}{path}"
    headers = {
        "Authorization": auth,
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if partition_key is not None:
        headers["x-ms-documentdb-partitionkey"] = json.dumps([partition_key])

    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        raise RuntimeError(f"HTTP {e.code}: {err}") from e


def write_doc(doc_type: str, content: str, tags: list = None,
              source: str = "agent", doc_id: str = None) -> dict:
    """Write a document to Cosmos DB. Returns the created document."""
    _require_creds()
    doc_id = doc_id or f"{doc_type}-{datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:6]}"
    doc = {
        "id":         doc_id,
        "type":       doc_type,
        "content":    content,
        "tags":       tags or [],
        "source":     source,
        "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    }
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    result = _request("POST", f"/{coll_link}/docs",
                      body=doc, resource_type="docs",
                      resource_link=coll_link, partition_key=doc_type)
    return result


def read_doc(doc_id: str, doc_type: str) -> dict:
    """Read a document by id + type (partition key)."""
    _require_creds()
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    doc_link  = f"{coll_link}/docs/{doc_id}"
    return _request("GET", f"/{doc_link}",
                    resource_type="docs", resource_link=doc_link,
                    partition_key=doc_type)


def query_docs(sql: str, partition_key: str = None) -> list:
    """Run a SQL query. Returns list of documents."""
    _require_creds()
    coll_link = f"dbs/{DB}/colls/{CONTAINER}"
    headers_extra = {"x-ms-documentdb-isquery": "true",
                     "x-ms-max-item-count": "100"}
    if partition_key:
        headers_extra["x-ms-documentdb-query-enablecrosspartition"] = "false"

    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = _auth("POST", "docs", coll_link, date)
    url  = f"{ENDPOINT}/{coll_link}/docs"
    headers = {
        "Authorization": auth,
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": "application/query+json",
        "Accept": "application/json",
        "x-ms-documentdb-isquery": "true",
        "x-ms-max-item-count": "100",
        "x-ms-documentdb-query-enablecrosspartition": "true",
    }
    if partition_key:
        headers["x-ms-documentdb-partitionkey"] = json.dumps([partition_key])
        headers["x-ms-documentdb-query-enablecrosspartition"] = "false"

    body = json.dumps({"query": sql, "parameters": []}).encode()
    req  = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
            return result.get("Documents", [])
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        raise RuntimeError(f"HTTP {e.code}: {err}") from e


def main():
    parser = argparse.ArgumentParser(description="Crunch Cosmos DB memory tool")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # write
    wp = sub.add_parser("write", help="Write a document")
    wp.add_argument("--type",    required=True, help="Document type (partition key)")
    wp.add_argument("--content", required=True, help="Text content")
    wp.add_argument("--tags",    default="",    help="Comma-separated tags")
    wp.add_argument("--source",  default="agent")
    wp.add_argument("--id",      default=None,  help="Custom doc ID (auto-generated if omitted)")

    # read
    rp = sub.add_parser("read", help="Read a document by id + type")
    rp.add_argument("--id",   required=True)
    rp.add_argument("--type", required=True)

    # query
    qp = sub.add_parser("query", help="Run a SQL query")
    qp.add_argument("--sql",            required=True)
    qp.add_argument("--partition-key",  default=None)

    # recent — shorthand for latest N docs of a given type
    rep = sub.add_parser("recent", help="Show recent documents")
    rep.add_argument("--type",  default=None, help="Filter by type")
    rep.add_argument("--limit", type=int, default=5)

    args = parser.parse_args()

    if args.cmd == "write":
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        result = write_doc(args.type, args.content, tags=tags, source=args.source, doc_id=args.id)
        print(f"✅ Wrote: {result['id']}  (type={result['type']})")

    elif args.cmd == "read":
        doc = read_doc(args.id, args.type)
        print(json.dumps(doc, indent=2))

    elif args.cmd == "query":
        docs = query_docs(args.sql, partition_key=getattr(args, "partition_key", None))
        print(json.dumps(docs, indent=2))

    elif args.cmd == "recent":
        if args.type:
            sql = f"SELECT TOP {args.limit} * FROM c WHERE c.type='{args.type}' ORDER BY c._ts DESC"
        else:
            sql = f"SELECT TOP {args.limit} * FROM c ORDER BY c._ts DESC"
        docs = query_docs(sql)
        for d in docs:
            ts = d.get("created_at", d.get("_ts", "?"))
            print(f"[{ts}] ({d.get('type','?')}) {str(d.get('content',''))[:120]}")


if __name__ == "__main__":
    main()
