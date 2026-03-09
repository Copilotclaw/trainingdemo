#!/usr/bin/env python3
"""
Write a memory document to Azure Cosmos DB.

Usage:
  python write.py --type memory --content "..." --tags "tag1,tag2" \
                  --source session --session-id "abc123"

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
import uuid
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


def write_memory(endpoint, key, doc):
    """Write a document to the memories container."""
    db = "crunch"
    container = "memories"
    resource_link = f"dbs/{db}/colls/{container}"
    url = f"{endpoint.rstrip('/')}/{resource_link}/docs"

    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = cosmos_auth("post", "docs", resource_link, date, key)

    payload = json.dumps(doc).encode("utf-8")
    req = Request(url, data=payload, method="POST")
    req.add_header("Authorization", auth)
    req.add_header("x-ms-date", date)
    req.add_header("x-ms-version", "2018-12-31")
    req.add_header("Content-Type", "application/json")
    req.add_header("x-ms-documentdb-partitionkey", f'["{doc["type"]}"]')

    try:
        with urlopen(req) as resp:
            result = json.loads(resp.read())
            return result
    except HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"❌ HTTP {e.code}: {body}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Write a memory to Cosmos DB")
    parser.add_argument("--type", required=True,
                        choices=["memory", "decision", "fact", "episodic", "heartbeat"],
                        help="Memory type (partition key)")
    parser.add_argument("--content", required=True, help="Memory content")
    parser.add_argument("--tags", default="", help="Comma-separated tags")
    parser.add_argument("--source", default="session",
                        choices=["heartbeat", "session", "agent"],
                        help="Source of this memory")
    parser.add_argument("--session-id", default="", help="Session identifier")
    args = parser.parse_args()

    endpoint = os.environ.get("COSMOS_ENDPOINT")
    key = os.environ.get("COSMOS_KEY")

    if not endpoint or not key:
        print("❌ COSMOS_ENDPOINT and COSMOS_KEY env vars required", file=sys.stderr)
        sys.exit(1)

    doc = {
        "id": str(uuid.uuid4()),
        "type": args.type,
        "content": args.content,
        "tags": [t.strip() for t in args.tags.split(",") if t.strip()],
        "source": args.source,
        "session_id": args.session_id,
        "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    }

    result = write_memory(endpoint, key, doc)
    print(f"✅ Written: {result['id']} [{result['type']}]")
    return result


if __name__ == "__main__":
    main()
