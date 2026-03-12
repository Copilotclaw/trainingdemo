#!/usr/bin/env python3
"""
Provision Azure Cosmos DB for MongoDB API using ARM REST API directly.
Bypasses Azure CLI (which needs resourcegroups/read) by calling ARM endpoints
with a bearer token obtained from the service principal credentials.

Usage:
  python3 arm-provision-mongo.py            # create account + DB + collection
  python3 arm-provision-mongo.py --get-key  # fetch primary key + store MONGO_URI secret
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ARM = "https://management.azure.com"
API_ACCOUNT = "2023-04-15"
API_DB = "2023-04-15"


def get_token(creds: dict) -> str:
    url = f"https://login.microsoftonline.com/{creds['tenantId']}/oauth2/v2.0/token"
    body = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": creds["clientId"],
        "client_secret": creds["clientSecret"],
        "scope": "https://management.azure.com/.default",
    }).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["access_token"]


def arm_request(token: str, method: str, path: str, body=None):
    url = f"{ARM}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def wait_for_account(token: str, sub: str, rg: str, account: str, timeout=600):
    path = f"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}?api-version={API_ACCOUNT}"
    deadline = time.time() + timeout
    while time.time() < deadline:
        status, body = arm_request(token, "GET", path)
        if status == 200:
            state = body.get("properties", {}).get("provisioningState", "")
            if state == "Succeeded":
                return body
            print(f"  ⏳ Provisioning state: {state} — waiting...")
        time.sleep(15)
    raise TimeoutError(f"Account {account} did not reach Succeeded state in {timeout}s")


def provision(creds: dict, account: str, rg: str, location: str):
    sub = creds["subscriptionId"]
    token = get_token(creds)
    print(f"✅ Token acquired for SP {creds['clientId'][:8]}...")

    # 1 — Check if account already exists
    path_account = f"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}?api-version={API_ACCOUNT}"
    status, body = arm_request(token, "GET", path_account)
    if status == 200 and body.get("properties", {}).get("provisioningState") == "Succeeded":
        print(f"ℹ️ Account '{account}' already exists — skipping creation")
    elif status in (200, 201, 404):
        print(f"Creating Cosmos DB account '{account}' (MongoDB API)...")
        payload = {
            "location": location,
            "kind": "MongoDB",
            "properties": {
                "databaseAccountOfferType": "Standard",
                "apiProperties": {"serverVersion": "7.0"},
                "consistencyPolicy": {"defaultConsistencyLevel": "Session"},
                "locations": [{"locationName": location, "failoverPriority": 0, "isZoneRedundant": False}],
            },
        }
        status2, body2 = arm_request(token, "PUT", path_account, payload)
        if status2 not in (200, 201, 202):
            print(f"❌ Failed to create account: HTTP {status2}")
            print(json.dumps(body2, indent=2))
            sys.exit(1)
        print(f"  Account accepted (HTTP {status2}), waiting for provisioning...")
        wait_for_account(token, sub, rg, account)
        print(f"✅ Account '{account}' provisioned")
    else:
        print(f"❌ Unexpected response checking account: HTTP {status}")
        print(json.dumps(body, indent=2))
        sys.exit(1)

    # 2 — Create database 'crunch'
    path_db = f"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}/mongodbDatabases/crunch?api-version={API_DB}"
    status, body = arm_request(token, "GET", path_db)
    if status == 200:
        print("ℹ️ Database 'crunch' already exists — skipping")
    else:
        print("Creating database 'crunch'...")
        payload = {"properties": {"resource": {"id": "crunch"}, "options": {"throughput": 400}}}
        status2, body2 = arm_request(token, "PUT", path_db, payload)
        if status2 not in (200, 201, 202):
            print(f"❌ Failed to create database: HTTP {status2}")
            print(json.dumps(body2, indent=2))
            sys.exit(1)
        print("✅ Database 'crunch' created")

    # 3 — Create collection 'memories'
    path_col = f"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}/mongodbDatabases/crunch/collections/memories?api-version={API_DB}"
    status, body = arm_request(token, "GET", path_col)
    if status == 200:
        print("ℹ️ Collection 'memories' already exists — skipping")
    else:
        print("Creating collection 'memories'...")
        payload = {
            "properties": {
                "resource": {
                    "id": "memories",
                    "shardKey": {"type": "Hash"},
                    "indexes": [{"key": {"keys": ["_id"]}}],
                }
            }
        }
        status2, body2 = arm_request(token, "PUT", path_col, payload)
        if status2 not in (200, 201, 202):
            print(f"❌ Failed to create collection: HTTP {status2}")
            print(json.dumps(body2, indent=2))
            sys.exit(1)
        print("✅ Collection 'memories' created")


def get_key_and_store_secret(creds: dict, account: str, rg: str):
    sub = creds["subscriptionId"]
    token = get_token(creds)

    path_keys = f"/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DocumentDB/databaseAccounts/{account}/listKeys?api-version={API_ACCOUNT}"
    status, body = arm_request(token, "POST", path_keys)
    if status != 200:
        print(f"❌ Failed to get keys: HTTP {status}")
        print(json.dumps(body, indent=2))
        sys.exit(1)

    primary_key = body["primaryMasterKey"]
    mongo_uri = (
        f"mongodb://{account}:{primary_key}@{account}.mongo.cosmos.azure.com:10255/"
        f"?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@{account}@"
    )

    # Store as GitHub secret
    gh_token = os.environ.get("GH_TOKEN", "")
    result = subprocess.run(
        ["gh", "secret", "set", "MONGO_URI", "--body", mongo_uri, "--repo", "Copilotclaw/copilotclaw"],
        env={**os.environ, "GH_TOKEN": gh_token},
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"❌ Failed to store secret: {result.stderr}")
        sys.exit(1)

    print(f"✅ MONGO_URI secret stored")
    print(f"🔑 Account: {account}")
    print(f"📍 Host: {account}.mongo.cosmos.azure.com:10255")


def main():
    raw = os.environ.get("AZURE_CREDENTIALS", "")
    if not raw:
        print("❌ AZURE_CREDENTIALS not set")
        sys.exit(1)
    creds = json.loads(raw)

    account = os.environ.get("ACCOUNT_NAME", "crunch-mongo")
    rg = os.environ.get("RESOURCE_GROUP", "crunch-memory-rg")
    location = os.environ.get("LOCATION", "eastus")

    if "--get-key" in sys.argv:
        get_key_and_store_secret(creds, account, rg)
    else:
        provision(creds, account, rg, location)


if __name__ == "__main__":
    main()
