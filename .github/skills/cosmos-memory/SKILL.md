# 🧠 cosmos-memory

Persistent memory layer using Azure Cosmos DB (NoSQL, always-free tier).

Crunch's brain that survives across sessions, runners, and repo migrations.

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `COSMOS_ENDPOINT` | Cosmos DB account endpoint URL |
| `COSMOS_KEY` | Cosmos DB primary master key |

Provisioned by: `.github/workflows/cosmos-provision.yml`

## Database Layout

- **Account**: `crunch-memory` (Azure, free tier: 1000 RU/s, 25 GB)
- **Database**: `crunch`
- **Container**: `memories` (partition key: `/type`)

## Memory Document Schema

```json
{
  "id": "<uuid>",
  "type": "memory|decision|fact|episodic|heartbeat",
  "content": "...",
  "tags": ["..."],
  "source": "heartbeat|session|agent",
  "session_id": "...",
  "created_at": "2026-01-01T00:00:00Z"
}
```

## Usage

### Write a memory

```bash
python .github/skills/cosmos-memory/scripts/write.py \
  --type memory \
  --content "Marcus prefers dark mode on everything" \
  --tags "preferences,marcus" \
  --source session \
  --session-id "$SESSION_ID"
```

### Read recent memories

```bash
# All types, last 20
python .github/skills/cosmos-memory/scripts/read.py

# Filter by type
python .github/skills/cosmos-memory/scripts/read.py --type heartbeat --limit 5

# Search by keyword
python .github/skills/cosmos-memory/scripts/read.py --search "dark mode"
```

## Environment Variables

Scripts read from env vars (set in workflow or exported locally):

```bash
export COSMOS_ENDPOINT="https://crunch-memory.documents.azure.com:443/"
export COSMOS_KEY="your-primary-key"
```
