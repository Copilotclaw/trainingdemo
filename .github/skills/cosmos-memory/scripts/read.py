#!/usr/bin/env python3
"""
Read memories from Azure Cosmos DB.

Usage:
  python read.py                          # last 20 memories (all types)
  python read.py --type heartbeat --limit 5
  python read.py --search "dark mode"
  python read.py --type memory --search "preferences" --limit 10

Env vars required:
  COSMOS_ENDPOINT   - Cosmos DB account endpoint
  COSMOS_KEY        - Cosmos DB primary master key
"""

import argparse
import datetime
import hashlib
import hmac
import json
import os
import sys
from base64 import b64decode, b64encode
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import HTTPError


def cosmos_auth(verb, resource_type, resource_link, date, key):
    """Generate Cosmos DB master key auth token."""
    key_bytes = b64decode(key)
    string_to_sign = f"{verb.lower()}\n{resource_type.lower()}\n{resource_link}\n{date.lower()}\n\n"
    sig = b64encode(
        hmac.new(key_bytes, string_to_sign.encode("utf-8"), hashlib.sha256).digest()
    ).decode("utf-8")
    return quote(f"type=master&ver=1.0&sig={sig}")


def query_memories(endpoint, key, sql, params=None):
    """Execute a SQL query against the memories container."""
    db = "crunch"
    container = "memories"
    resource_link = f"dbs/{db}/colls/{container}"
    url = f"{endpoint.rstrip('/')}/{resource_link}/docs"

    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = cosmos_auth("post", "docs", resource_link, date, key)

    body = {"query": sql}
    if params:
        body["parameters"] = params

    payload = json.dumps(body).encode("utf-8")
    req = Request(url, data=payload, method="POST")
    req.add_header("Authorization", auth)
    req.add_header("x-ms-date", date)
    req.add_header("x-ms-version", "2018-12-31")
    req.add_header("Content-Type", "application/query+json")
    req.add_header("x-ms-documentdb-isquery", "True")
    req.add_header("x-ms-documentdb-query-enablecrosspartition", "True")

    try:
        with urlopen(req) as resp:
            result = json.loads(resp.read())
            return result.get("Documents", [])
    except HTTPError as e:
        body_text = e.read().decode("utf-8")
        print(f"❌ HTTP {e.code}: {body_text}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Read memories from Cosmos DB")
    parser.add_argument("--type", default=None,
                        choices=["memory", "decision", "fact", "episodic", "heartbeat"],
                        help="Filter by memory type")
    parser.add_argument("--search", default=None,
                        help="Keyword search in content")
    parser.add_argument("--limit", type=int, default=20,
                        help="Max results (default: 20)")
    parser.add_argument("--json", action="store_true",
                        help="Output as raw JSON")
    args = parser.parse_args()

    endpoint = os.environ.get("COSMOS_ENDPOINT")
    key = os.environ.get("COSMOS_KEY")

    if not endpoint or not key:
        print("❌ COSMOS_ENDPOINT and COSMOS_KEY env vars required", file=sys.stderr)
        sys.exit(1)

    conditions = []
    params = []

    if args.type:
        conditions.append("c.type = @type")
        params.append({"name": "@type", "value": args.type})

    if args.search:
        conditions.append("CONTAINS(LOWER(c.content), LOWER(@search))")
        params.append({"name": "@search", "value": args.search})

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    sql = f"SELECT TOP {args.limit} * FROM c {where} ORDER BY c.created_at DESC"

    docs = query_memories(endpoint, key, sql, params if params else None)

    if args.json:
        print(json.dumps(docs, indent=2))
        return

    if not docs:
        print("(no memories found)")
        return

    for doc in docs:
        ts = doc.get("created_at", "")[:19].replace("T", " ")
        typ = doc.get("type", "?")
        src = doc.get("source", "?")
        tags = ", ".join(doc.get("tags", []))
        content = doc.get("content", "")
        tag_str = f" [{tags}]" if tags else ""
        print(f"[{ts}] {typ}/{src}{tag_str}")
        print(f"  {content}")
        print()


if __name__ == "__main__":
    main()
