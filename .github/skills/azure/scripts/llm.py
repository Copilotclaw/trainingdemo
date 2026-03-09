#!/usr/bin/env python3
"""
Azure LLM query script. One key (AZURE_APIKEY) for all models.
On rate limit: retries with backoff, then falls back to another Azure model.

Usage:
    python llm.py --model <model> --prompt <prompt>
                  [--system <system_prompt>]
                  [--max-tokens <n>]
                  [--temperature <f>]
                  [--json]        # output raw JSON response
                  [--no-fallback] # disable model fallback

Environment:
    AZURE_ENDPOINT   - Azure AI base URL
    AZURE_APIKEY     - Azure AI key (same key for all models)

Available models (Azure):
    model-router              (Azure AI model router — picks best model automatically)
    Kimi-K2.5
    grok-4-1-fast-non-reasoning
    grok-4-1-fast-reasoning
"""

import argparse
import json
import os
import sys
import time

try:
    from openai import OpenAI, AzureOpenAI, RateLimitError, APIStatusError
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Model routing tables
# ---------------------------------------------------------------------------

# Azure deployments that use AzureOpenAI client (require api-version header)
AZURE_NATIVE_MODELS = {"model-router"}

# Azure deployments that use plain OpenAI client (OpenAI-compatible endpoint)
AZURE_OPENAI_COMPAT_MODELS = {
    "Kimi-K2.5",
    "grok-4-1-fast-non-reasoning",
    "grok-4-1-fast-reasoning",
}

# Azure model-to-model fallback (same AZURE_APIKEY)
AZURE_MODEL_FALLBACK = {
    "Kimi-K2.5": "grok-4-1-fast-non-reasoning",
    "grok-4-1-fast-non-reasoning": "Kimi-K2.5",
    "grok-4-1-fast-reasoning": "Kimi-K2.5",
    "model-router": "Kimi-K2.5",
}

AZURE_API_VERSION = "2024-12-01-preview"
MAX_RETRIES = 3
BASE_BACKOFF = 5  # seconds


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def build_messages(prompt: str, system: str | None) -> list[dict]:
    msgs = []
    if system:
        msgs.append({"role": "system", "content": system})
    msgs.append({"role": "user", "content": prompt})
    return msgs


def call_with_retry(fn, max_retries: int = MAX_RETRIES):
    """Call fn(), retrying on RateLimitError with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return fn()
        except RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            wait = BASE_BACKOFF * (2 ** attempt)
            print(f"[azure] Rate limited. Waiting {wait}s (attempt {attempt + 1}/{max_retries})…", file=sys.stderr)
            time.sleep(wait)
        except APIStatusError as e:
            if e.status_code == 429:
                if attempt == max_retries - 1:
                    raise
                wait = BASE_BACKOFF * (2 ** attempt)
                print(f"[azure] 429 status. Waiting {wait}s (attempt {attempt + 1}/{max_retries})…", file=sys.stderr)
                time.sleep(wait)
            else:
                raise


# ---------------------------------------------------------------------------
# Azure calls
# ---------------------------------------------------------------------------

def call_azure_native(endpoint: str, api_key: str, model: str, messages: list,
                       max_tokens: int, temperature: float):
    """Call via AzureOpenAI client (model-router, etc.)."""
    client = AzureOpenAI(
        api_version=AZURE_API_VERSION,
        azure_endpoint=endpoint,
        api_key=api_key,
    )
    return call_with_retry(lambda: client.chat.completions.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
    ))


def call_azure_compat(endpoint: str, api_key: str, model: str, messages: list,
                       max_tokens: int, temperature: float):
    """Call via plain OpenAI client (OpenAI-compatible Azure endpoint)."""
    client = OpenAI(
        base_url=endpoint,
        api_key=api_key,
    )
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
    parser = argparse.ArgumentParser(description="Query Azure LLM")
    parser.add_argument("--model", default="model-router", help="Model deployment name")
    parser.add_argument("--prompt", required=True, help="User prompt")
    parser.add_argument("--system", default=None, help="System prompt")
    parser.add_argument("--max-tokens", type=int, default=4096, dest="max_tokens")
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--json", action="store_true", dest="output_json",
                        help="Print raw JSON response object")
    parser.add_argument("--no-fallback", action="store_true", dest="no_fallback",
                        help="Disable Azure model fallback")
    parser.add_argument("--log-usage", dest="log_usage", default=None,
                        help="Append JSON usage line to this file (or set AZURE_CALL_LOG env var)")
    args = parser.parse_args()

    # Allow env var as default for log path
    if args.log_usage is None:
        args.log_usage = os.environ.get("AZURE_CALL_LOG")

    azure_endpoint = os.environ.get("AZURE_ENDPOINT", "").rstrip("/")
    azure_key = os.environ.get("AZURE_APIKEY", "")

    if not azure_endpoint or not azure_key:
        print("ERROR: AZURE_ENDPOINT and AZURE_APIKEY must be set.", file=sys.stderr)
        sys.exit(1)

    messages = build_messages(args.prompt, args.system)
    response = None
    used_model = args.model

    try:
        if args.model in AZURE_NATIVE_MODELS:
            response = call_azure_native(azure_endpoint, azure_key, args.model,
                                          messages, args.max_tokens, args.temperature)
        else:
            response = call_azure_compat(azure_endpoint, azure_key, args.model,
                                          messages, args.max_tokens, args.temperature)

    except (RateLimitError, APIStatusError) as e:
        if args.no_fallback:
            print(f"ERROR: Rate limited and fallback disabled. {e}", file=sys.stderr)
            sys.exit(1)

        fallback = AZURE_MODEL_FALLBACK.get(args.model)
        if not fallback:
            print(f"ERROR: Rate limited on {args.model} and no fallback configured. {e}", file=sys.stderr)
            sys.exit(1)

        print(f"[azure] Rate limited on {args.model}. Falling back to {fallback}…", file=sys.stderr)
        try:
            response = call_azure_compat(azure_endpoint, azure_key, fallback,
                                          messages, args.max_tokens, args.temperature)
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
            pass  # never fail on logging

    if args.output_json:
        print(response.model_dump_json(indent=2))
    else:
        content = response.choices[0].message.content
        if used_model != args.model:
            print(f"[via azure fallback: {used_model}]")
        elif hasattr(response, "model") and response.model:
            print(f"[model: {response.model}]")
        print(content)


if __name__ == "__main__":
    main()
