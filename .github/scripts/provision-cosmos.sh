#!/bin/bash
# provision-cosmos.sh — Create Crunch's persistent Cosmos DB memory layer
# Idempotent: safe to re-run. Uses free tier (once per subscription).
# Requires: AZURE_CREDENTIALS env var (JSON: clientId, clientSecret, tenantId, subscriptionId)
# Outputs: COSMOS_ENDPOINT and COSMOS_KEY (last 4 chars shown for confirmation)

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-}"
LOCATION="${LOCATION:-northeurope}"
COSMOS_ACCOUNT="${COSMOS_ACCOUNT:-crunch-memory}"
DB_NAME="crunch"
CONTAINER_NAME="memories"

echo "🦃 Crunch Cosmos DB provisioner starting..."

# Parse credentials
CLIENT_ID=$(echo "$AZURE_CREDENTIALS"    | python3 -c "import json,sys; print(json.load(sys.stdin)['clientId'])")
CLIENT_SECRET=$(echo "$AZURE_CREDENTIALS" | python3 -c "import json,sys; print(json.load(sys.stdin)['clientSecret'])")
TENANT_ID=$(echo "$AZURE_CREDENTIALS"    | python3 -c "import json,sys; print(json.load(sys.stdin)['tenantId'])")
SUBSCRIPTION_ID=$(echo "$AZURE_CREDENTIALS" | python3 -c "import json,sys; print(json.load(sys.stdin)['subscriptionId'])")

echo "📍 Subscription: ${SUBSCRIPTION_ID}"
echo "📍 Region: ${LOCATION}"

# Login
az login --service-principal \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --tenant "$TENANT_ID" \
  --output none

az account set --subscription "$SUBSCRIPTION_ID"
echo "✅ Logged in to Azure"

# Resource group — find an existing one or create
if [ -z "$RESOURCE_GROUP" ]; then
  echo "🔍 No resource group specified — listing available groups..."
  FIRST_RG=$(az group list --query "[0].name" -o tsv 2>/dev/null || echo "")
  if [ -n "$FIRST_RG" ]; then
    RESOURCE_GROUP="$FIRST_RG"
    echo "✅ Using existing resource group: '$RESOURCE_GROUP'"
  else
    RESOURCE_GROUP="crunch-persistent"
    echo "⏳ No existing resource groups found — creating '$RESOURCE_GROUP'..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    echo "✅ Resource group '$RESOURCE_GROUP' created"
  fi
else
  EXISTING_RG=$(az group show --name "$RESOURCE_GROUP" --query name -o tsv 2>/dev/null || echo "")
  if [ -z "$EXISTING_RG" ]; then
    echo "⏳ Creating resource group '$RESOURCE_GROUP'..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    echo "✅ Resource group '$RESOURCE_GROUP' created"
  else
    echo "✅ Resource group '$RESOURCE_GROUP' already exists"
  fi
fi

# Cosmos DB account (idempotent — check first to avoid free-tier collision)
EXISTING_COSMOS=$(az cosmosdb show --name "$COSMOS_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query name -o tsv 2>/dev/null || echo "")
if [ -z "$EXISTING_COSMOS" ]; then
  echo "⏳ Creating Cosmos DB account '$COSMOS_ACCOUNT' (this takes ~2min)..."
  az cosmosdb create \
    --name "$COSMOS_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-free-tier true \
    --default-consistency-level Session \
    --locations regionName="$LOCATION" \
    --output none
  echo "✅ Cosmos DB account created"
else
  echo "✅ Cosmos DB account '$COSMOS_ACCOUNT' already exists"
fi

# Database (idempotent)
EXISTING_DB=$(az cosmosdb sql database show --account-name "$COSMOS_ACCOUNT" --name "$DB_NAME" --resource-group "$RESOURCE_GROUP" --query name -o tsv 2>/dev/null || echo "")
if [ -z "$EXISTING_DB" ]; then
  az cosmosdb sql database create \
    --account-name "$COSMOS_ACCOUNT" \
    --name "$DB_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output none
  echo "✅ Database '$DB_NAME' created"
else
  echo "✅ Database '$DB_NAME' already exists"
fi

# Container (idempotent)
EXISTING_CONTAINER=$(az cosmosdb sql container show --account-name "$COSMOS_ACCOUNT" --database-name "$DB_NAME" --name "$CONTAINER_NAME" --resource-group "$RESOURCE_GROUP" --query name -o tsv 2>/dev/null || echo "")
if [ -z "$EXISTING_CONTAINER" ]; then
  az cosmosdb sql container create \
    --account-name "$COSMOS_ACCOUNT" \
    --database-name "$DB_NAME" \
    --name "$CONTAINER_NAME" \
    --partition-key-path "/type" \
    --resource-group "$RESOURCE_GROUP" \
    --output none
  echo "✅ Container '$CONTAINER_NAME' created"
else
  echo "✅ Container '$CONTAINER_NAME' already exists"
fi

# Get endpoint and key
COSMOS_ENDPOINT=$(az cosmosdb show \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query primaryMasterKey -o tsv)

echo ""
echo "🎉 Cosmos DB ready!"
echo "   Endpoint: $COSMOS_ENDPOINT"
echo "   Key: ...${COSMOS_KEY: -4}"
echo ""
echo "📌 Next: Add these as GitHub secrets:"
echo "   COSMOS_ENDPOINT = $COSMOS_ENDPOINT"
echo "   COSMOS_KEY = <see workflow artifacts or Azure portal>"

# Export for subsequent steps in CI
echo "COSMOS_ENDPOINT=$COSMOS_ENDPOINT" >> "${GITHUB_ENV:-/dev/null}"
echo "COSMOS_KEY=$COSMOS_KEY" >> "${GITHUB_ENV:-/dev/null}"
