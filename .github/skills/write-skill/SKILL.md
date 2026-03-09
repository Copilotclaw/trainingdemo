---
name: write-skill
description: Create a new Copilot CLI skill and commit it so all future sessions can use it. Use this to extend your own capabilities permanently.
allowed-tools: "*"
---

# Write a New Skill

Skills are Markdown files auto-loaded by Copilot CLI from `.github/skills/<name>/SKILL.md`.
Once committed, every future session in this repo can use them — this is how you evolve.

## Skill file format

```markdown
---
name: skill-name           # kebab-case, max 64 chars
description: What this skill does and when to invoke it. Include triggers.  # max 1024 chars
allowed-tools: "*"         # or specific: ["read", "write", "shell(git:*)"]
user-invocable: true       # whether the user can invoke with /skill-name
---

# Skill Title

Body — injected into the conversation when the skill fires.
```

## Anatomy of a skill directory

Only `SKILL.md` is required. Optional subdirectories:

```
skill-name/
├── SKILL.md              (required)
├── scripts/              executable scripts — use when same code would be rewritten every time
├── references/           docs/schemas loaded into context as needed — keeps SKILL.md lean
└── assets/               templates, images, files used in output (not loaded into context)
```

## Progressive disclosure principle

The context window is shared. Be economical:

1. **Description** (~100 tokens) — always in context. This is the trigger — be specific about *when* to invoke.
2. **SKILL.md body** — loaded when the skill fires. Keep under 500 lines.
3. **Bundled resources** — loaded only when the agent explicitly reads them.

Default assumption: the agent is already very smart. Only add context it doesn't already have.

When a skill supports multiple variants (e.g. different frameworks, providers), keep core workflow in SKILL.md and put variant details in `references/` files. The agent reads only what it needs.

## Design guidelines

- **Description is the trigger** — include explicit "Use when:" conditions. It's read before the body, so "When to Use" sections in the body are useless.
- **Imperative form** — "Run the script", not "You should run the script".
- **No READMEs or changelogs** — skills are for agents, not humans.
- **Name** — lowercase kebab-case, verb-led preferred (e.g. `fetch-pdf`, `sync-calendar`).
- **One skill, one thing** — multiple focused skills beat one giant one.

## Steps

1. Write a clear `name` and `description` with explicit trigger conditions.
2. Identify reusable scripts, references, or assets worth bundling.
3. Create the files:
   ```bash
   mkdir -p .github/skills/<name>
   # write SKILL.md (and any scripts/, references/, assets/)
   ```
4. Commit and push:
   ```bash
   git add .github/skills/<name>
   git commit -m "skill: add <name>"
   git push origin main
   ```
5. Tell the user what the skill does and when it activates.
6. Iterate after real usage — update based on what worked and what didn't.
