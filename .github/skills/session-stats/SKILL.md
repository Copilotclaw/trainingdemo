---
name: session-stats
description: Show model usage stats and CI run times. Auto-appended at end of every response as a stats footer. Also invoke explicitly when user asks about usage, cost, run times, or stats.
allowed-tools: ["shell(bash:*)", "shell(gh:*)"]
---

# Session Stats Footer

⚠️ **MANDATORY**: Append this footer to **every single response** — no exceptions, no skipping.
**NEVER compose from memory.** Always run the scripts below fresh each turn.

## Format

```
---
📊 **Session** | premium: N (models) | free: N | standard: N | 🔷 **Azure**: model: Nx/Ktok | 🎟️ **Copilot**: 47/300 (15%) | 🏃 **CI**: ✅ 14:09 3m9s · ✅ 14:05 44s
```

Omit a section silently if its script fails or returns no data.

## Steps — run ALL of these every turn

### 1. Model usage (SQL — this session)

```sql
SELECT tier, COUNT(*) as n, GROUP_CONCAT(DISTINCT model) as models
FROM model_calls GROUP BY tier;
```

If table is empty, show `0` for all tiers.

### 2. Azure LLM usage

```bash
bash .github/skills/session-stats/scripts/azure-stats.sh
```

Output: `grok-fast: 3x/1234tok` or `0 calls`. Omit section if `0 calls`.

Azure calls log to `/tmp/crunch_azure_calls.jsonl` when `AZURE_CALL_LOG` is set.
To enable: set env var `AZURE_CALL_LOG=/tmp/crunch_azure_calls.jsonl` before calling `llm.py`,
or pass `--log-usage /tmp/crunch_azure_calls.jsonl` directly.

### 3. Copilot premium quota

```bash
bash .github/skills/session-stats/scripts/premium-usage.sh copilotclaw
```

Output: `47 / 300 requests (15%)`. **Setup**: `COPILOT_PAT` needs "Plan" user permission — see AGENTS.md.

### 4. CI run times

```bash
bash .github/skills/session-stats/scripts/ci-stats.sh 3
```

Condense to inline: `✅ 14:09 3m9s · ✅ 14:05 44s · ❌ 13:52 18s`

## Model tier reference

| Tier | Models |
|------|--------|
| free | `gpt-4.1`, `gpt-5-mini`, `gpt-5.1-codex-mini`, `claude-haiku-4.5` |
| standard | `claude-sonnet-4.5`, `gpt-5.1-codex`, `gpt-5.2-codex`, `gpt-5.3-codex` |
| premium | `claude-sonnet-4.6`, `claude-opus-4.5`, `claude-opus-4.6` |

## Tracking rule

Before every `task` tool call, insert into `model_calls`:
```sql
INSERT INTO model_calls (model, tier) VALUES ('gpt-4.1', 'free');
```

Count me (Claude Sonnet 4.6) as **1 premium call per user turn** — insert on first tool use each turn.

Create the table if it doesn't exist:
```sql
CREATE TABLE IF NOT EXISTS model_calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  model TEXT NOT NULL,
  tier TEXT NOT NULL,
  note TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

