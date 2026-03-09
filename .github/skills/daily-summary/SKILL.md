---
name: daily-summary
description: Post a daily narrative summary to issue #10. Collects last 24h of commits, issues, and CI runs, synthesizes via Grok into readable prose. Run manually or invoked by heartbeat.
allowed-tools: ["shell(bash:*)", "shell(gh:*)", "shell(git:*)"]
---

# Daily Summary Skill

Posts a daily digest to issue #10 that summarizes what happened in the last 24 hours.

## Usage

```bash
bash .github/skills/daily-summary/scripts/daily-summary.sh
# or for a dry run (no posting):
bash .github/skills/daily-summary/scripts/daily-summary.sh --dry-run
```

## What it collects

1. **Commits** — all non-merge commits in the last 24h
2. **Issues opened** — with labels
3. **Issues closed** — titles
4. **CI runs** — count of successes and failures
5. **Memory log** — last 10 entries for context

## What it produces

A short narrative paragraph (written by Grok as Crunch) followed by a collapsible raw data section.

## When to invoke

- Manually when asked "post a daily summary" or "give me a day summary"
- Can be wired into heartbeat.yml for daily scheduled posting (post once per day, not every heartbeat)

## Requirements

- `BILLING_PAT` — for posting to issue #10 as Copilotclaw account
- `AZURE_APIKEY` + `AZURE_ENDPOINT` — for Grok synthesis (gracefully falls back if missing)
