#!/usr/bin/env python3
"""
LLM query via PI coding agent → DashScope (OpenAI-compatible).

PI acts as the coding tool layer on top of DashScope, keeping usage within
Alibaba's Coding Plan ToS (PI is an approved coding tool).

Interface is compatible with llm.py for easy migration:
    python pi-llm.py --model qwen3-coder-plus --prompt "Your prompt"

Environment:
    ALIKEY  - Alibaba Cloud API key (passed through to PI via models.json)

Setup (run once):
    bash .github/skills/ali/scripts/pi-setup.sh

Differences from llm.py:
    - No --json / --image / --no-fallback / --temperature / --max-tokens flags
    - PI handles its own retry/backoff
    - Model must be configured in models.json (defaults work for standard models)
"""

import argparse
import os
import subprocess
import sys
import tempfile


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PI_SETUP = os.path.join(SCRIPT_DIR, "pi-setup.sh")

DEFAULT_MODEL = "qwen3-coder-plus"
MODEL_MAP = {
    "qwen3-coder-plus": "qwen3-coder-plus",
    "qwen3-coder-next": "qwen3-coder-next",
    "qwen3.5-plus": "qwen3.5-plus",
}


def ensure_pi_ready():
    """Install PI and configure DashScope if needed."""
    result = subprocess.run(
        ["bash", PI_SETUP],
        capture_output=False,
        text=True,
    )
    if result.returncode != 0:
        print("[pi-llm] pi-setup.sh failed", file=sys.stderr)
        sys.exit(1)


def run_pi(model: str, prompt: str, system: str | None = None) -> str:
    """Run PI in print mode and return the response text."""
    mapped_model = MODEL_MAP.get(model, model)

    cmd = [
        "pi",
        "--provider", "dashscope",
        "--model", mapped_model,
        "--no-tools",
        "--no-session",
        "-p",
    ]

    if system:
        cmd += ["--system-prompt", system]

    # Write prompt to temp file to safely handle special characters/newlines
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(prompt)
        tmpfile = f.name

    try:
        cmd.append(f"@{tmpfile}")
        # Run from /tmp to avoid loading AGENTS.md / .pi/ from the repo dir
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=120, cwd="/tmp"
        )
        if result.returncode != 0:
            print(f"[pi-llm] PI exited with code {result.returncode}", file=sys.stderr)
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            sys.exit(1)
        return result.stdout.strip()
    finally:
        os.unlink(tmpfile)


def main():
    parser = argparse.ArgumentParser(
        description="Query DashScope LLM via PI coding agent"
    )
    parser.add_argument(
        "--model", default=DEFAULT_MODEL,
        help=f"Model name (default: {DEFAULT_MODEL})"
    )
    parser.add_argument("--prompt", required=True, help="User prompt")
    parser.add_argument("--system", default=None, help="System prompt")
    args = parser.parse_args()

    ensure_pi_ready()
    output = run_pi(model=args.model, prompt=args.prompt, system=args.system)
    print(output)


if __name__ == "__main__":
    main()
