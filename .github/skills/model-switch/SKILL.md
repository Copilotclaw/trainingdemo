---
name: model-switch
description: Set or display the active model tier for sub-agent calls. Use when user says "use cheap models", "economy mode", "switch to free models", "use X model", "what model are you using", or asks to change model preferences. Reads/writes model preference to memory.log.
allowed-tools: ["shell(echo:*)", "shell(git:*)", "shell(bash:*)", "shell(tail:*)"]
---

# Model Switch

Crunch uses sub-agents (via the `task` tool) for most work. Each call has a `model` parameter — choosing wisely saves premium requests.

## Available Models by Tier

| Tier | Models | Use when |
|------|--------|----------|
| **Free/cheap** | `gpt-4.1`, `gpt-5-mini`, `gpt-5.1-codex-mini`, `claude-haiku-4.5` | Exploration, simple edits, commands, searches |
| **Standard** | `claude-sonnet-4.5`, `gpt-5.1-codex`, `gpt-5.2-codex`, `gpt-5.3-codex` | Medium complexity code, multi-file changes |
| **Premium** | `claude-sonnet-4.6` (current default), `claude-opus-4.5`, `claude-opus-4.6` | Hard reasoning, architecture, critical decisions |

> Note: `explore` and `task` agents already default to Haiku (cheap). The savings are mainly in `general-purpose` and `code-review` agents.

## Setting a Preference

Determine what the user wants, then write it to memory and confirm:

```bash
# Example: switching to economy mode
echo "[$(date -u '+%Y-%m-%d %H:%M')] MODEL PREFERENCE: economy — use gpt-4.1 for general-purpose agents, claude-haiku-4.5 for task/explore agents. Only escalate to sonnet for truly complex reasoning." >> memory.log
git add memory.log && git commit -m "memory: set model preference to economy mode

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" && git push origin main
```

## Mode Presets

**Economy mode** (`gpt-4.1` for general-purpose, haiku for others):
- Tell the user: sub-agents will use `gpt-4.1` by default, escalating only for hard tasks.
- Log: `MODEL PREFERENCE: economy`

**Standard mode** (`claude-sonnet-4.5` for general-purpose):
- Balanced. Good reasoning without burning premium quota.
- Log: `MODEL PREFERENCE: standard`

**Full-power mode** (`claude-sonnet-4.6` / opus):
- Reserve for genuinely hard problems.
- Log: `MODEL PREFERENCE: full-power`

## Reading Current Preference

```bash
rg -i "MODEL PREFERENCE" memory.log 2>/dev/null | tail -1
```

## After Setting

Tell the user which model tier is now active and what it means for their requests. Then apply it: for the rest of the session, use the logged model in all `task` tool calls.
