---
name: install-skill
description: Discover and install skills from the ClawHub marketplace (https://clawhub.ai). Use when the user asks to find a skill, install a capability, or when you think a community skill might help with the current task.
allowed-tools: "*"
---

# Install a Skill from ClawHub

[ClawHub](https://clawhub.ai) is a public marketplace of agent skills — reusable `.github/skills/` bundles anyone can publish and install. No API key, no login required for installation.

## Discover skills

Browse or search at https://clawhub.ai/skills

Or search from the command line:
```bash
npx clawhub@latest search <query>
```

## Install a skill

```bash
# Install into the project's .github/skills/ directory
npx clawhub@latest install <skill-name>
```

ClawHub installs into `.claude/skills/` by default — move it to `.github/skills/` so it's loaded by Copilot CLI:
```bash
npx clawhub@latest install <skill-name>
# then if it landed in .claude/skills/:
mv .claude/skills/<skill-name> .github/skills/<skill-name>
```

## Commit and persist it

Once installed, commit so future sessions inherit it:
```bash
git add .github/skills/<skill-name>
git commit -m "skill: install <skill-name> from ClawHub"
git push origin main
```

## Then use it

Tell the user what was installed, what it does, and how to invoke it (either automatically or via `/<skill-name>`).

## Notable skills on ClawHub

- `self-improving-agent` — captures failures and corrections for continuous improvement
- `find-skills` — helps discover skills that match what you need
- `proactive-agent` — patterns for anticipating needs, autonomous improvement
- `github` — extended GitHub CLI patterns beyond what's built in
- `tavily-search` — AI-optimized web search (needs TAVILY_API_KEY)
- `gog` — Google Workspace (Gmail, Calendar, Drive, Sheets)
- `slack` — Slack control via API
- `notion` — Notion API integration
- `trello` — Trello board management

Browse the full list: https://clawhub.ai/skills
