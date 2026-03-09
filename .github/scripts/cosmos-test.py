#!/usr/bin/env python3
"""
cosmos-test.py — Verify Cosmos DB round-trip: write a memory doc, read it back.
Requires: COSMOS_ENDPOINT and COSMOS_KEY env vars.
Uses Cosmos DB REST API directly (no SDK needed).
"""

import os, sys, json, hashlib, hmac, base64, datetime, urllib.request, urllib.error

ENDPOINT = os.environ.get("COSMOS_ENDPOINT", "").rstrip("/")
KEY      = os.environ.get("COSMOS_KEY", "")
DB       = "crunch"
COLL     = "memories"

if not ENDPOINT or not KEY:
    print("❌ COSMOS_ENDPOINT and COSMOS_KEY env vars required")
    sys.exit(1)


def cosmos_auth(verb, resource_type, resource_link, date):
    """Generate Cosmos DB master key authorization header."""
    text = f"{verb.lower()}\n{resource_type.lower()}\n{resource_link}\n{date.lower()}\n\n"
    key_bytes = base64.b64decode(KEY)
    sig = base64.b64encode(
        hmac.new(key_bytes, text.encode("utf-8"), hashlib.sha256).digest()
    ).decode()
    return urllib.parse.quote(f"type=master&ver=1.0&sig={sig}")


import urllib.parse


def cosmos_request(method, path, body=None, resource_type="", resource_link=""):
    date = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    auth = cosmos_auth(method, resource_type, resource_link, date)
    url  = f"{ENDPOINT}{path}"
    headers = {
        "Authorization": auth,
        "x-ms-date": date,
        "x-ms-version": "2018-12-31",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if resource_type == "docs":
        headers["x-ms-documentdb-partitionkey"] = '["memory"]'

    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"❌ HTTP {e.code}: {err}")
        raise


def main():
    print(f"🦃 Testing Cosmos DB at {ENDPOINT}")
    print(f"   DB: {DB}  Container: {COLL}")

    # --- WRITE ---
    doc_id   = "crunch-test-" + datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    doc      = {
        "id":         doc_id,
        "type":       "memory",
        "content":    "Crunch Cosmos DB test — write path verified 🎉",
        "tags":       ["test", "bootstrap"],
        "source":     "cosmos-test.py",
        "created_at": datetime.datetime.utcnow().isoformat() + "Z",
    }
    coll_link = f"dbs/{DB}/colls/{COLL}"
    result = cosmos_request(
        "POST",
        f"/{coll_link}/docs",
        body=doc,
        resource_type="docs",
        resource_link=coll_link,
    )
    written_id = result.get("id", "?")
    print(f"✅ Wrote doc: {written_id}")

    # --- READ BACK ---
    doc_link = f"{coll_link}/docs/{doc_id}"
    read_result = cosmos_request(
        "GET",
        f"/{doc_link}",
        resource_type="docs",
        resource_link=doc_link,
    )
    content = read_result.get("content", "")
    print(f"✅ Read back: {content}")

    if content == doc["content"]:
        print("\n🎉 Round-trip SUCCESS — Cosmos DB is live and working!")
    else:
        print("\n❌ Content mismatch on read-back!")
        sys.exit(1)


if __name__ == "__main__":
    main()
