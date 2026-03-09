---
name: idea-summary
description: Fetch all ideas from Copilotclaw/brainstorm issues, generate an AI narrative summary using Azure LLM, and update the brainstorm README. Use when asked to "summarize ideas", "update brainstorm readme", or "summarize the brainstorm".
allowed-tools: ["shell(bash:*)", "shell(gh:*)", "shell(python3:*)", "shell(curl:*)"]
---

# Idea Summary Skill

Fetches all ideas from `Copilotclaw/brainstorm` issues, uses Grok to write a narrative AI summary grouped by themes, and pushes an updated README to the brainstorm repo.

## Usage

```bash
bash .github/skills/idea-summary/scripts/summarize-ideas.sh
```

## What it does

1. Fetches all open + closed issues from `Copilotclaw/brainstorm`
2. Sends them to Grok (`grok-4-1-fast-non-reasoning`) for theme-based narrative summary
3. Rebuilds the README with:
   - **🤖 AI Summary** section at top (narrative, themed)
   - **Current Ideas** table grouped by label (`priority` / `exploring` / `idea` / `shelved`)
   - **Shipped / Closed** list
4. Pushes the updated README via GitHub Contents API

## Requirements

- `BILLING_PAT` — must have write access to `Copilotclaw/brainstorm`
- `AZURE_APIKEY` + `AZURE_ENDPOINT` — for Grok LLM call (falls back to count-only on failure)

## Invoke

Crunch: run `bash .github/skills/idea-summary/scripts/summarize-ideas.sh` whenever ideas change or Marcus asks for a summary update.
