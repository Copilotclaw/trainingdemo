#!/usr/bin/env python3
"""
Alibaba Cloud DashScope LLM query script (OpenAI-compatible API).
On rate limit: retries with backoff, then falls back to another model.

Usage:
    python llm.py --model <model> --prompt <prompt>
                  [--system <system_prompt>]
                  [--max-tokens <n>]
                  [--temperature <f>]
                  [--json]        # output raw JSON response
                  [--no-fallback] # disable model fallback
                  [--image <url>] # image URL for vision models

Environment:
    ALIKEY           - Alibaba Cloud API key
    ALIBASE or ALIURL - API base URL (DashScope compatible endpoint)
                        Default: https://coding-intl.dashscope.aliyuncs.com/v1

Available models:
    qwen3-coder-plus          Text generation, coding (DEFAULT)
    qwen3-coder-next          Text generation, coding (latest)
    qwen3.5-plus              Text + Vision + Deep Thinking
    qwen3-max-2026-01-23      Text + Deep Thinking (heavy reasoning)
    glm-5                     Text + Deep Thinking (Zhipu)
    glm-4.7                   Text + Deep Thinking (Zhipu)
    kimi-k2.5                 Text + Vision + Deep Thinking (Moonshot)
    MiniMax-M2.5              Text + Deep Thinking (MiniMax)
"""

import argparse
import json
import os
import sys
import time

try:
    from openai import OpenAI, RateLimitError, APIStatusError
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Model registry
# ---------------------------------------------------------------------------

DEFAULT_MODEL = "qwen3-coder-plus"
DEFAULT_BASE_URL = "https://coding-intl.dashscope.aliyuncs.com/v1"

# Models with vision capability
VISION_MODELS = {"qwen3.5-plus", "kimi-k2.5"}

# Model fallback chain
MODEL_FALLBACK = {
    "qwen3-coder-next": "qwen3-coder-plus",
    "qwen3-coder-plus": "qwen3-coder-next",
    "qwen3.5-plus": "qwen3-coder-plus",
    "qwen3-max-2026-01-23": "qwen3-coder-plus",
    "glm-5": "qwen3-coder-plus",
    "glm-4.7": "glm-5",
    "kimi-k2.5": "qwen3.5-plus",
    "MiniMax-M2.5": "qwen3-coder-plus",
}

MAX_RETRIES = 3
BASE_BACKOFF = 3  # seconds


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_client(base_url: str, api_key: str) -> OpenAI:
    return OpenAI(base_url=base_url, api_key=api_key)


def build_messages(prompt: str, system: str | None, image_url: str | None = None) -> list[dict]:
    msgs = []
    if system:
        msgs.append({"role": "system", "content": system})

    if image_url:
        msgs.append({
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": image_url}},
                {"type": "text", "text": prompt},
            ],
        })
    else:
        msgs.append({"role": "user", "content": prompt})

    return msgs


def call_with_retry(fn, max_retries: int = MAX_RETRIES):
    """Call fn(), retrying on rate limit with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return fn()
        except RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            wait = BASE_BACKOFF * (2 ** attempt)
            print(f"[ali] Rate limited. Waiting {wait}s (attempt {attempt + 1}/{max_retries})…", file=sys.stderr)
            time.sleep(wait)
        except APIStatusError as e:
            if e.status_code == 429:
                if attempt == max_retries - 1:
                    raise
                wait = BASE_BACKOFF * (2 ** attempt)
                print(f"[ali] 429 status. Waiting {wait}s (attempt {attempt + 1}/{max_retries})…", file=sys.stderr)
                time.sleep(wait)
            else:
                raise


def call_model(client: OpenAI, model: str, messages: list,
               max_tokens: int, temperature: float):
    return call_with_retry(lambda: client.chat.completions.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
    ))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Query Alibaba Cloud LLM (DashScope)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Model name (default: {DEFAULT_MODEL})")
    parser.add_argument("--prompt", required=True, help="User prompt")
    parser.add_argument("--system", default=None, help="System prompt")
    parser.add_argument("--max-tokens", type=int, default=4096, dest="max_tokens")
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--image", default=None, help="Image URL for vision models")
    parser.add_argument("--json", action="store_true", dest="output_json",
                        help="Print raw JSON response object")
    parser.add_argument("--no-fallback", action="store_true", dest="no_fallback",
                        help="Disable model fallback on rate limit")
    parser.add_argument("--log-usage", dest="log_usage", default=None,
                        help="Append JSON usage line to this file (or set ALI_CALL_LOG env var)")
    args = parser.parse_args()

    if args.log_usage is None:
        args.log_usage = os.environ.get("ALI_CALL_LOG")

    api_key = os.environ.get("ALIKEY", "")
    base_url = (
        os.environ.get("ALIBASE")
        or os.environ.get("ALIURL")
        or DEFAULT_BASE_URL
    ).rstrip("/")

    if not api_key:
        print("ERROR: ALIKEY environment variable must be set.", file=sys.stderr)
        sys.exit(1)

    if args.image and args.model not in VISION_MODELS:
        print(f"[ali] Warning: {args.model} may not support vision. Consider qwen3.5-plus or kimi-k2.5.", file=sys.stderr)

    client = get_client(base_url, api_key)
    messages = build_messages(args.prompt, args.system, args.image)
    response = None
    used_model = args.model

    try:
        response = call_model(client, args.model, messages, args.max_tokens, args.temperature)

    except (RateLimitError, APIStatusError) as e:
        if args.no_fallback:
            print(f"ERROR: Rate limited and fallback disabled. {e}", file=sys.stderr)
            sys.exit(1)

        fallback = MODEL_FALLBACK.get(args.model)
        if not fallback:
            print(f"ERROR: Rate limited on {args.model} and no fallback configured. {e}", file=sys.stderr)
            sys.exit(1)

        print(f"[ali] Rate limited on {args.model}. Falling back to {fallback}…", file=sys.stderr)
        try:
            response = call_model(client, fallback, messages, args.max_tokens, args.temperature)
            used_model = fallback
        except Exception as e2:
            print(f"ERROR: Fallback {fallback} also failed: {e2}", file=sys.stderr)
            sys.exit(1)

    if response is None:
        print("ERROR: No response received.", file=sys.stderr)
        sys.exit(1)

    # Log usage if requested
    if args.log_usage and hasattr(response, "usage") and response.usage:
        import datetime
        usage_entry = {
            "model": used_model,
            "prompt_tokens": response.usage.prompt_tokens or 0,
            "completion_tokens": response.usage.completion_tokens or 0,
            "total_tokens": response.usage.total_tokens or 0,
            "ts": datetime.datetime.utcnow().isoformat(),
        }
        try:
            with open(args.log_usage, "a") as f:
                f.write(json.dumps(usage_entry) + "\n")
        except Exception:
            pass

    if args.output_json:
        print(response.model_dump_json(indent=2))
    else:
        content = response.choices[0].message.content
        if used_model != args.model:
            print(f"[via ali fallback: {used_model}]")
        elif hasattr(response, "model") and response.model:
            print(f"[model: {response.model}]")
        print(content)


if __name__ == "__main__":
    main()
