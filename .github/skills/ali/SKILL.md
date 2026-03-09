---
name: ali
description: Query Alibaba Cloud DashScope LLM endpoints (Qwen, GLM, Kimi, MiniMax models). Generous subscription with vision support, fast responses, and deep thinking models. Use when you need LLM reasoning, summarization, code generation, vision tasks, or any task where calling an external model is useful. Primary LLM provider. Invoke with python .github/skills/ali/scripts/llm.py
allowed-tools: "*"
---

# Alibaba Cloud LLM Skill

Query Alibaba Cloud DashScope (OpenAI-compatible API). Fast, generous quota, vision support.

## Quick usage

```bash
python .github/skills/ali/scripts/llm.py \
  --model qwen3-coder-plus \
  --prompt "Your prompt here"
```

## Available models

| Model | Capabilities | Best for |
|-------|-------------|----------|
| `qwen3-coder-plus` | Text, Coding | **DEFAULT** — general tasks, code |
| `qwen3-coder-next` | Text, Coding | Latest coder, cutting-edge |
| `qwen3.5-plus` | Text + **Vision** + Deep Thinking | Vision tasks, complex reasoning |
| `qwen3-max-2026-01-23` | Text + Deep Thinking | Heavy reasoning |
| `glm-5` | Text + Deep Thinking | Alternative reasoning (Zhipu) |
| `glm-4.7` | Text + Deep Thinking | Zhipu lighter model |
| `kimi-k2.5` | Text + **Vision** + Deep Thinking | Vision + reasoning (Moonshot) |
| `MiniMax-M2.5` | Text + Deep Thinking | MiniMax model |

## Arguments

```
--model          Model name (default: qwen3-coder-plus)
--prompt         User prompt (required)
--system         System prompt (optional)
--max-tokens     Max output tokens (default: 4096)
--temperature    Sampling temperature (default: 0.7)
--image          Image URL for vision models (qwen3.5-plus, kimi-k2.5)
--json           Output raw JSON response
--no-fallback    Disable model fallback
--log-usage      Append usage JSON to file (or set ALI_CALL_LOG env var)
```

## Rate limit behaviour

On 429/rate limit:
1. Retries up to **3 times** with exponential backoff (3s, 6s, 12s)
2. After retries → falls back to next model in chain

## Required secrets

| Env var | Purpose |
|---------|---------|
| `ALIKEY` | Alibaba Cloud API key |
| `ALIBASE` or `ALIURL` | DashScope base URL (default: `https://dashscope.aliyuncs.com/compatible-mode/v1`) |

## Examples

```bash
# Quick coding task (default model)
python .github/skills/ali/scripts/llm.py \
  --prompt "Write a Python function to parse JSON from a string"

# Use vision model to analyze an image
python .github/skills/ali/scripts/llm.py \
  --model qwen3.5-plus \
  --image "https://example.com/diagram.png" \
  --prompt "Describe this architecture diagram"

# Deep reasoning with kimi
python .github/skills/ali/scripts/llm.py \
  --model kimi-k2.5 \
  --prompt "Analyze this code for race conditions: $(cat server.py)"

# Fast summarization, no fallback
python .github/skills/ali/scripts/llm.py \
  --model qwen3-coder-plus \
  --prompt "Summarize: $(cat README.md)" \
  --no-fallback

# Get raw JSON response
python .github/skills/ali/scripts/llm.py \
  --model qwen3-max-2026-01-23 \
  --prompt "Explain monads" \
  --json
```

## When to use this skill

- **Primary LLM** for all reasoning, summarization, code generation
- **Vision tasks** — use `qwen3.5-plus` or `kimi-k2.5` with `--image`
- Faster and more generous quota than Azure
- Building block for other skills (pipe output, chain calls)
- Complexity evaluation, brainstorming, analysis
