---
name: azure
description: Query Azure AI Foundry LLM endpoints (Kimi-K2.5, model-router, grok-4-1-fast variants). Handles Azure rate limits with exponential backoff and falls back to OpenRouter automatically. Use when you need LLM reasoning, summarization, translation, generation, or any task where calling an external model is useful. Invoke with python .github/skills/azure/scripts/llm.py
allowed-tools: "*"
---

# Azure LLM Skill

Query Azure AI Foundry endpoints. Automatic rate limit handling + OpenRouter fallback.

## Quick usage

```bash
python .github/skills/azure/scripts/llm.py \
  --model model-router \
  --prompt "Your prompt here"
```

## Available models

| Deployment name | Notes |
|----------------|-------|
| `model-router` | Azure picks the best model automatically (AzureOpenAI client) |
| `Kimi-K2.5` | Moonshot's K2.5 — strong at reasoning and code |
| `grok-4-1-fast-non-reasoning` | Grok fast, no chain-of-thought |
| `grok-4-1-fast-reasoning` | Grok fast with reasoning |

## Arguments

```
--model          Model deployment name (default: model-router)
--prompt         User prompt (required)
--system         System prompt (optional)
--max-tokens     Max output tokens (default: 4096)
--temperature    Sampling temperature (default: 0.7)
--json           Output raw JSON response
--no-fallback    Disable OpenRouter fallback
```

## Rate limit behaviour

Azure endpoints have ~20 RPM and token limits. The script:
1. Retries up to **3 times** with exponential backoff (5s, 10s, 20s)
2. After retries exhausted → falls back to **OpenRouter** automatically

OpenRouter fallback model mapping:
- `model-router` → `anthropic/claude-3.5-sonnet`
- `Kimi-K2.5` → `moonshotai/kimi-k2`
- `grok-4-1-fast-*` → `x-ai/grok-4`

## Required secrets

| Env var | Purpose |
|---------|---------|
| `AZURE_ENDPOINT` | Azure AI base URL (e.g. `https://aineu-marcus.cognitiveservices.azure.com/`) |
| `AZURE_APIKEY` | Azure API key |
| `OPENROUTER_API_KEY` | OpenRouter key (optional, enables fallback) |

## Examples

```bash
# Quick question via model-router
python .github/skills/azure/scripts/llm.py \
  --model model-router \
  --prompt "Explain Docker in one paragraph"

# Use Kimi for code review
python .github/skills/azure/scripts/llm.py \
  --model Kimi-K2.5 \
  --system "You are a senior code reviewer. Be concise." \
  --prompt "$(cat myfile.py)"

# Grok with reasoning, get raw JSON
python .github/skills/azure/scripts/llm.py \
  --model grok-4-1-fast-reasoning \
  --prompt "What is 17 * 23? Show your work." \
  --json

# Summarise a file, no fallback
python .github/skills/azure/scripts/llm.py \
  --model Kimi-K2.5 \
  --prompt "Summarise: $(cat README.md)" \
  --no-fallback
```

## When to use this skill

- Any task where calling an external LLM would produce better results than reasoning alone
- Summarisation, translation, code generation, analysis of large text
- When you want to test a specific model's output
- As a building block for other skills (pipe output, chain calls)
