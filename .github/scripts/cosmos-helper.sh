#!/usr/bin/env bash
# cosmos-helper.sh — Cosmos DB NoSQL document operations (Crunch's persistent brain)
#
# Required env vars:
#   COSMOS_ACCOUNT    — Cosmos DB account name (e.g. crunch-cosmos)
#   COSMOS_RG         — Resource group (e.g. crunch-rg)
#   COSMOS_DB         — Database name (default: crunch)
#   COSMOS_CONTAINER  — Container name (default: memories)
#
# Usage:
#   cosmos-write '{"id":"x","type":"memory","content":"..."}'
#   cosmos-read  <document-id>
#   cosmos-query "SELECT TOP 20 * FROM c WHERE c.type='memory' ORDER BY c._ts DESC"

set -euo pipefail

COSMOS_DB="${COSMOS_DB:-crunch}"
COSMOS_CONTAINER="${COSMOS_CONTAINER:-memories}"

: "${COSMOS_ACCOUNT:?COSMOS_ACCOUNT not set}"
: "${COSMOS_RG:?COSMOS_RG not set}"

cosmos-write() {
  local doc="$1"
  az cosmosdb sql document create \
    --account-name  "$COSMOS_ACCOUNT" \
    --resource-group "$COSMOS_RG" \
    --database-name "$COSMOS_DB" \
    --container-name "$COSMOS_CONTAINER" \
    --body "$doc" \
    --output json
}

cosmos-read() {
  local id="$1"
  local partition="${2:-$id}"
  az cosmosdb sql document show \
    --account-name  "$COSMOS_ACCOUNT" \
    --resource-group "$COSMOS_RG" \
    --database-name "$COSMOS_DB" \
    --container-name "$COSMOS_CONTAINER" \
    --name "$id" \
    --partition-key-value "$partition" \
    --output json
}

cosmos-query() {
  local query="$1"
  az cosmosdb sql query \
    --account-name  "$COSMOS_ACCOUNT" \
    --resource-group "$COSMOS_RG" \
    --database-name "$COSMOS_DB" \
    --container-name "$COSMOS_CONTAINER" \
    --query-text "$query" \
    --output json
}

cosmos-upsert() {
  local doc="$1"
  az cosmosdb sql document create \
    --account-name  "$COSMOS_ACCOUNT" \
    --resource-group "$COSMOS_RG" \
    --database-name "$COSMOS_DB" \
    --container-name "$COSMOS_CONTAINER" \
    --body "$doc" \
    --output json 2>/dev/null || \
  az cosmosdb sql document replace \
    --account-name  "$COSMOS_ACCOUNT" \
    --resource-group "$COSMOS_RG" \
    --database-name "$COSMOS_DB" \
    --container-name "$COSMOS_CONTAINER" \
    --body "$doc" \
    --output json
}

# If called directly (not sourced), dispatch to the right function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-}"
  shift || true
  case "$CMD" in
    write)   cosmos-write  "$@" ;;
    read)    cosmos-read   "$@" ;;
    query)   cosmos-query  "$@" ;;
    upsert)  cosmos-upsert "$@" ;;
    *) echo "Usage: cosmos-helper.sh <write|read|query|upsert> [args]" >&2; exit 1 ;;
  esac
fi
