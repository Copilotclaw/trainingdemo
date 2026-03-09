#!/usr/bin/env bash
# az-login.sh — Service Principal login helper
# Source this or call it; sets active Azure subscription for the session.
#
# Required env vars (GitHub Secrets):
#   AZURE_CLIENT_ID       — Service Principal app ID
#   AZURE_CLIENT_SECRET   — SP client secret
#   AZURE_TENANT_ID       — Azure AD tenant ID
#   AZURE_SUBSCRIPTION_ID — Target subscription
#
# Usage:
#   source .github/scripts/az-login.sh
#   bash .github/scripts/az-login.sh

set -euo pipefail

: "${AZURE_CLIENT_ID:?AZURE_CLIENT_ID not set}"
: "${AZURE_CLIENT_SECRET:?AZURE_CLIENT_SECRET not set}"
: "${AZURE_TENANT_ID:?AZURE_TENANT_ID not set}"
: "${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID not set}"

az login \
  --service-principal \
  --username  "$AZURE_CLIENT_ID" \
  --password  "$AZURE_CLIENT_SECRET" \
  --tenant    "$AZURE_TENANT_ID" \
  --output none

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

echo "✅ Azure login OK — subscription: $AZURE_SUBSCRIPTION_ID"
