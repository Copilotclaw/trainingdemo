#!/usr/bin/env bash
# cosmos-provision.sh — One-time provisioning of Crunch's Cosmos DB infrastructure
#
# Run ONCE after az-login.sh. Safe to re-run — uses --if-not-exists where possible.
#
# Required env vars (after az-login):
#   AZURE_SUBSCRIPTION_ID
#   COSMOS_ACCOUNT  (default: crunch-cosmos)
#   COSMOS_RG       (default: crunch-rg)
#   COSMOS_LOCATION (default: westeurope)

set -euo pipefail

COSMOS_ACCOUNT="${COSMOS_ACCOUNT:-crunch-cosmos}"
COSMOS_RG="${COSMOS_RG:-crunch-rg}"
COSMOS_LOCATION="${COSMOS_LOCATION:-westeurope}"
COSMOS_DB="${COSMOS_DB:-crunch}"

echo "🏗️  Provisioning Crunch's Azure infrastructure..."
echo "   Account:  $COSMOS_ACCOUNT"
echo "   RG:       $COSMOS_RG"
echo "   Location: $COSMOS_LOCATION"

# Resource group
echo "📦 Creating resource group..."
az group create \
  --name "$COSMOS_RG" \
  --location "$COSMOS_LOCATION" \
  --output none

# Cosmos DB account (NoSQL, free tier)
echo "🧠 Creating Cosmos DB account (free tier, this takes ~2 min)..."
az cosmosdb create \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$COSMOS_RG" \
  --locations regionName="$COSMOS_LOCATION" failoverPriority=0 \
  --default-consistency-level Session \
  --enable-free-tier true \
  --output none

# Database
echo "📂 Creating database: $COSMOS_DB ..."
az cosmosdb sql database create \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$COSMOS_RG" \
  --name "$COSMOS_DB" \
  --output none

# memories container (partition key: /type)
echo "📋 Creating container: memories ..."
az cosmosdb sql container create \
  --account-name "$COSMOS_ACCOUNT" \
  --resource-group "$COSMOS_RG" \
  --database-name "$COSMOS_DB" \
  --name memories \
  --partition-key-path /type \
  --throughput 400 \
  --output none

echo ""
echo "✅ Done! Now grab the credentials:"
echo ""
echo "COSMOS_ACCOUNT=$COSMOS_ACCOUNT"
echo "COSMOS_RG=$COSMOS_RG"
echo ""
echo "Endpoint:"
az cosmosdb show \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$COSMOS_RG" \
  --query documentEndpoint \
  --output tsv

echo ""
echo "Primary key (add as COSMOS_KEY secret):"
az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$COSMOS_RG" \
  --query primaryMasterKey \
  --output tsv

echo ""
echo "Add these to GitHub Secrets:"
echo "  COSMOS_ACCOUNT=$COSMOS_ACCOUNT"
echo "  COSMOS_RG=$COSMOS_RG"
echo "  COSMOS_ENDPOINT=<endpoint above>"
echo "  COSMOS_KEY=<key above>"
