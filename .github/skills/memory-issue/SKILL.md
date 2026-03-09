---
name: memory-issue
description: Store and recall memory facts as GitHub Issues. Each fact = one closed issue with crunch/memory label. Searchable by keyword now, future-semantic-ready. Use for episodic memories that benefit from discrete searchable entries.
allowed-tools: ["shell(gh:*)", "shell(bash:*)"]
---

# memory-issue

GitHub Issues as episodic memory. Each memory = a closed issue with `crunch/memory` label.
Invisible in normal issue views. Searchable. Future-semantic-ready.

## Labels

| Label | Meaning |
|-------|---------|
| `crunch/memory` | Required on all memory issues |
| `memory/user` | About Marcus — preferences, style, personal facts |
| `memory/infra` | Infrastructure, secrets, workflow gotchas |
| `memory/decision` | Architecture/design decisions with rationale |
| `memory/event` | One-off events, experiments, milestones |

## Store a memory

```bash
bash .github/skills/memory-issue/scripts/store.sh \
  "Title of the memory" \
  "Full body text with context, date, tags" \
  "memory/user"   # optional category label
```

The script:
1. Creates the issue with `crunch/memory` + optional category label
2. Immediately closes it
3. Prints the issue URL

## Recall memories

```bash
# Semantic recall (Grok LLM reranks all memories — best for vague or conceptual queries)
# Requires: AZURE_ENDPOINT + AZURE_APIKEY. Falls back to text search if unavailable.
bash .github/skills/memory-issue/scripts/recall-smart.sh "what was the cat's name"

# Keyword search across all memories
bash .github/skills/memory-issue/scripts/recall.sh "search query"

# Filter by category
bash .github/skills/memory-issue/scripts/recall.sh "search query" memory/user

# List all memories (no query)
bash .github/skills/memory-issue/scripts/recall.sh ""
```

## Update a memory

Add a comment to the existing issue (preserves history):

```bash
gh issue comment <number> \
  --repo Copilotclaw/copilotclaw \
  --body "Update: [new information, date]"
```

## Memory body format

Write bodies in this shape for consistency:

```markdown
**Memory entry** — YYYY-MM-DD

[The fact, context, rationale. Be specific. Include names, numbers, reasons.]

**Tags**: comma, separated, keywords
```

## When to use this vs entity files

| Use `memory-issue` | Use `state/memory/*.md` |
|-------------------|------------------------|
| Episodic facts (one-off events, experiments) | Canonical structured facts (current state) |
| Things you want to search semantically | Things you always want in context |
| Growing log of memories over time | Single source of truth per entity |

They complement each other. Entity files = "what is true now". Memory issues = "what happened, what we learned".
