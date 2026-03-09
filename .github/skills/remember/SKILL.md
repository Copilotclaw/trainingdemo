---
name: remember
description: Store an important fact, preference, or decision in memory for future sessions. Invoke when the user says "remember this", "remember:", or when you learn something that future-you should know.
allowed-tools: ["shell(echo:*)", "shell(date:*)", "shell(bash:*)", "shell(git:*)"]
---

# Remember

Two-tier memory system. Write to both:
1. **`memory.log`** — fast append scratch-pad, grep-friendly
2. **`state/memory/<entity>.md`** — structured canonical store, one file per entity

## Tier 1: memory.log (quick scratch)

```bash
echo "[$(date -u '+%Y-%m-%d %H:%M')] THE FACT TO REMEMBER." >> memory.log
```

## Tier 2: entity files (structured)

Pick the right file:

| File | What goes here |
|------|---------------|
| `state/memory/marcus.md` | Marcus's preferences, family, requests, style |
| `state/memory/crunch.md` | My identity, skills built, milestones |
| `state/memory/infrastructure.md` | Secrets, workflows, infra gotchas |
| `state/memory/decisions.md` | Architecture & design decisions with rationale |

Edit the relevant section with the new fact. Be surgical — update existing entries rather than duplicating.

## Commit both

```bash
git add memory.log state/memory/
git commit -m "memory: [short description of what was learned]"
git push origin main
```

## Search memory

```bash
# Quick grep across everything
rg -i "search term" memory.log state/memory/ 2>/dev/null

# Recent scratch entries
tail -20 memory.log

# Specific entity
cat state/memory/marcus.md
```

## What NOT to remember

- Transient task details (what you did this session)
- Things already in README or code comments
- Vague entries like "user wants good code"
