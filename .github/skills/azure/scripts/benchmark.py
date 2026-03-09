#!/usr/bin/env python3
"""
🦃 Crunch's LLM Benchmark — Kimi-K2.5 vs Grok-4.1-Fast

Tests 5 categories: reasoning, code, knowledge, creativity, instruction-following.
Judge: model-router (Azure picks best available model to score answers).

Usage:
    python .github/skills/azure/scripts/benchmark.py

Env:
    AZURE_ENDPOINT, AZURE_APIKEY
"""

import json
import os
import sys
import time
import textwrap
from datetime import datetime

# Make sure openai is available
try:
    from openai import OpenAI, AzureOpenAI, RateLimitError, APIStatusError
except ImportError:
    print("pip install openai", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MODELS = [
    "Kimi-K2.5",
    "grok-4-1-fast-non-reasoning",
    "grok-4-1-fast-reasoning",
]

JUDGE_MODEL = "grok-4-1-fast-non-reasoning"  # fastest, most reliable; model-router requires different endpoint
AZURE_API_VERSION = "2024-12-01-preview"
MAX_RETRIES = 3
BASE_BACKOFF = 8

# ---------------------------------------------------------------------------
# Benchmark prompts — 5 categories, 1 prompt each
# ---------------------------------------------------------------------------

TESTS = [
    {
        "id": "reasoning",
        "category": "🧠 Logical Reasoning",
        "prompt": (
            "Three boxes are labeled 'Apples', 'Oranges', and 'Mixed'. "
            "All three labels are WRONG. You may draw ONE fruit from ONE box. "
            "Which box do you pick from to correctly label all three boxes? "
            "Explain your logic step by step."
        ),
        "ideal_points": ["pick from 'Mixed' box", "whatever you draw tells you what's in it",
                         "then the other two are determined by process of elimination"],
    },
    {
        "id": "code",
        "category": "💻 Code Generation",
        "prompt": (
            "Write a Python function `find_duplicates(lst)` that returns a list of elements "
            "that appear more than once in the input list, preserving the order of first duplicate appearance. "
            "Include docstring, type hints, and 3 test cases with assert statements."
        ),
        "ideal_points": ["correct duplicate logic", "type hints present", "docstring present",
                         "3 assert test cases", "order preserved"],
    },
    {
        "id": "knowledge",
        "category": "📚 World Knowledge",
        "prompt": (
            "Explain the concept of 'emergence' in complex systems. "
            "Give 3 concrete examples from different domains (biology, technology, social). "
            "Keep it under 250 words."
        ),
        "ideal_points": ["defines emergence clearly", "biology example", "technology example",
                         "social example", "concise (under 250 words)"],
    },
    {
        "id": "creativity",
        "category": "🎨 Creative + Lateral Thinking",
        "prompt": (
            "You are a product manager. Your team has built an app that tells users "
            "the exact time they will die (based on actuarial data + lifestyle inputs). "
            "Come up with 5 genuinely creative, non-obvious monetisation strategies for it."
        ),
        "ideal_points": ["5 distinct strategies", "at least 2 genuinely non-obvious ideas",
                         "practical feasibility mentioned", "some wit/creativity"],
    },
    {
        "id": "instruction",
        "category": "📋 Instruction Following",
        "prompt": (
            "Respond ONLY with a valid JSON object. No markdown fences, no explanation, no preamble. "
            "The object must have exactly these keys: "
            "\"capital\": the capital of Japan, "
            "\"prime\": the smallest prime number greater than 100, "
            "\"haiku\": a 5-7-5 haiku about debugging code."
        ),
        "ideal_points": ["valid parseable JSON", "Tokyo", "101", "haiku is 5-7-5",
                         "no extra text outside JSON"],
    },
]

# ---------------------------------------------------------------------------
# Azure callers
# ---------------------------------------------------------------------------

def _retry(fn):
    for attempt in range(MAX_RETRIES):
        try:
            return fn()
        except (RateLimitError, APIStatusError) as e:
            status = getattr(e, 'status_code', None)
            if status and status != 429:
                raise
            if attempt == MAX_RETRIES - 1:
                raise
            wait = BASE_BACKOFF * (2 ** attempt)
            print(f"      ⏳ rate limited, waiting {wait}s…", file=sys.stderr)
            time.sleep(wait)


def call_azure_compat(endpoint, key, model, messages, max_tokens=1024):
    client = OpenAI(base_url=endpoint, api_key=key)
    resp = _retry(lambda: client.chat.completions.create(
        model=model, messages=messages, max_tokens=max_tokens, temperature=0.7,
    ))
    # Some models return None content — normalise to empty string
    if resp and resp.choices and resp.choices[0].message.content is None:
        resp.choices[0].message.content = ""
    return resp


def call_azure_native(endpoint, key, model, messages, max_tokens=1024):
    client = AzureOpenAI(api_version=AZURE_API_VERSION, azure_endpoint=endpoint, api_key=key)
    return _retry(lambda: client.chat.completions.create(
        model=model, messages=messages, max_tokens=max_tokens, temperature=0.3,
    ))


# ---------------------------------------------------------------------------
# Judge
# ---------------------------------------------------------------------------

JUDGE_SYSTEM = """You are an impartial LLM benchmark judge. 
Score the given answer on a scale of 0-10. 
Be strict but fair. Consider: correctness, completeness, clarity, following instructions.
Respond ONLY with valid JSON: {"score": <0-10>, "reasoning": "<one sentence>"}"""


def judge_answer(endpoint, key, test, model_answer):
    prompt = (
        f"QUESTION:\n{test['prompt']}\n\n"
        f"ANSWER TO SCORE:\n{model_answer}\n\n"
        f"IDEAL POINTS TO CHECK:\n" + "\n".join(f"- {p}" for p in test["ideal_points"])
    )
    msgs = [{"role": "system", "content": JUDGE_SYSTEM},
            {"role": "user", "content": prompt}]
    try:
        resp = call_azure_compat(endpoint, key, JUDGE_MODEL, msgs, max_tokens=200)
        raw = (resp.choices[0].message.content or "").strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        return json.loads(raw)
    except Exception as e:
        return {"score": -1, "reasoning": f"judge failed: {e}"}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    endpoint = os.environ.get("AZURE_ENDPOINT", "").rstrip("/")
    key = os.environ.get("AZURE_APIKEY", "")
    if not endpoint or not key:
        print("ERROR: AZURE_ENDPOINT and AZURE_APIKEY required", file=sys.stderr)
        sys.exit(1)

    print(f"\n🦃 Crunch's LLM Benchmark — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"   Models: {', '.join(MODELS)}")
    print(f"   Judge:  {JUDGE_MODEL}")
    print(f"   Tests:  {len(TESTS)}\n")
    print("=" * 70)

    results = {m: [] for m in MODELS}
    answers = {}  # (model, test_id) -> answer text

    # --- Run all models on all tests ---
    for test in TESTS:
        print(f"\n{test['category']}")
        print(f"  Q: {test['prompt'][:80]}…" if len(test['prompt']) > 80 else f"  Q: {test['prompt']}")
        msgs = [{"role": "user", "content": test["prompt"]}]

        for model in MODELS:
            print(f"  ⏩ {model}…", end=" ", flush=True)
            t0 = time.time()
            try:
                resp = call_azure_compat(endpoint, key, model, msgs, max_tokens=600)
                answer = resp.choices[0].message.content.strip()
                elapsed = time.time() - t0
                print(f"✅ ({elapsed:.1f}s, {len(answer)} chars)")
            except Exception as e:
                answer = f"[ERROR: {e}]"
                elapsed = time.time() - t0
                print(f"❌ {e}")
            answers[(model, test["id"])] = (answer, elapsed)
            # Small pause to avoid hammering rate limits
            time.sleep(2)

    # --- Judge all answers ---
    print("\n\n" + "=" * 70)
    print(f"⚖️  JUDGING ({JUDGE_MODEL} scoring each answer 0-10)…")
    print("=" * 70)

    for test in TESTS:
        print(f"\n{test['category']}")
        for model in MODELS:
            answer, elapsed = answers[(model, test["id"])]
            if answer.startswith("[ERROR"):
                score_data = {"score": 0, "reasoning": "model errored"}
            else:
                print(f"  🔍 Judging {model}…", end=" ", flush=True)
                score_data = judge_answer(endpoint, key, test, answer)
                print(f"  → {score_data.get('score', '?')}/10 — {score_data.get('reasoning', '')}")
                time.sleep(3)  # respect judge rate limit
            results[model].append({
                "test": test["id"],
                "score": score_data.get("score", 0),
                "reasoning": score_data.get("reasoning", ""),
                "latency": elapsed,
            })

    # --- Final scores ---
    print("\n\n" + "=" * 70)
    print("🏆  FINAL RESULTS")
    print("=" * 70)

    totals = {}
    for model in MODELS:
        scores = [r["score"] for r in results[model] if r["score"] >= 0]
        avg_lat = sum(r["latency"] for r in results[model]) / len(results[model])
        total = sum(scores)
        avg = total / len(scores) if scores else 0
        totals[model] = {"total": total, "avg": avg, "latency": avg_lat, "scores": scores}

    # Sort by total score
    ranked = sorted(totals.items(), key=lambda x: x[1]["total"], reverse=True)

    medals = ["🥇", "🥈", "🥉"]
    for i, (model, data) in enumerate(ranked):
        medal = medals[i] if i < len(medals) else "  "
        per_test = " | ".join(f"{r['test'][:6]}:{r['score']}" for r in results[model])
        print(f"\n{medal} {model}")
        print(f"   Total: {data['total']}/50  Avg: {data['avg']:.1f}/10  Latency: {data['latency']:.1f}s avg")
        print(f"   By test: {per_test}")

    print("\n" + "=" * 70)

    # Per-test breakdown
    print("\n📊 PER-TEST BREAKDOWN\n")
    header = f"{'Test':<12}" + "".join(f"{m[:20]:<22}" for m in MODELS)
    print(header)
    print("-" * (12 + 22 * len(MODELS)))
    for test in TESTS:
        row = f"{test['id']:<12}"
        for model in MODELS:
            r = next(x for x in results[model] if x["test"] == test["id"])
            row += f"{r['score']}/10 ({r['latency']:.1f}s)        "[:22]
        print(row)

    # --- Crunch's verdict ---
    winner = ranked[0][0]
    print(f"\n🦃 CRUNCH'S VERDICT:")
    print(f"   Winner: {winner} — {ranked[0][1]['total']}/50 points")

    # Save results to JSON
    out_path = "state/benchmark_results.json"
    payload = {
        "timestamp": datetime.now().isoformat(),
        "models": MODELS,
        "judge": JUDGE_MODEL,
        "results": {m: results[m] for m in MODELS},
        "totals": totals,
        "ranked": [r[0] for r in ranked],
    }
    os.makedirs("state", exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"\n   Full results saved to {out_path}")

    # Sample answers for inspection
    print("\n📝 SAMPLE ANSWERS (reasoning test):")
    for model in MODELS:
        answer, _ = answers[(model, "reasoning")]
        print(f"\n--- {model} ---")
        print(textwrap.fill(answer[:500], width=70))
        if len(answer) > 500:
            print("  [truncated…]")


if __name__ == "__main__":
    main()
