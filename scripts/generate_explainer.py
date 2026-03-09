#!/usr/bin/env python3
"""
generate_explainer.py — Auto-generate an excalidraw-style HTML explainer for a Jupyter notebook.

Usage:
    python scripts/generate_explainer.py simple-rag-demo.ipynb
    python scripts/generate_explainer.py simple-rag-demo.ipynb --output explainer.html
    python scripts/generate_explainer.py simple-rag-demo.ipynb --output explainers/simple-rag-demo.html

Requires:
    ALIKEY env var (Alibaba DashScope API key) for LLM generation.
    Fallback: AZURE_API_KEY for Azure AI Foundry.

The script:
  1. Extracts text from all notebook cells (markdown + code)
  2. Asks an LLM to generate a structured description (JSON)
  3. Renders the description into a polished excalidraw-style HTML page
  4. Writes the HTML to the output file
"""

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
from pathlib import Path


# ---------------------------------------------------------------------------
# Notebook extraction
# ---------------------------------------------------------------------------

def extract_notebook_content(path: str) -> dict:
    """Extract key content from a notebook for LLM analysis."""
    with open(path) as f:
        nb = json.load(f)

    title = "Notebook"
    overview_lines = []
    steps = []
    code_snippets = []
    exercises = []

    for cell in nb["cells"]:
        src = "".join(cell["source"]).strip()
        if not src:
            continue

        if cell["cell_type"] == "markdown":
            if src.startswith("# "):
                title = src.split("\n")[0].lstrip("# ").strip()
                overview_lines.append(src)
            elif src.startswith("## Step") or re.match(r"^## \w", src):
                steps.append(src)
            elif "exercise" in src.lower() or "try" in src.lower():
                exercises.append(src)
            else:
                overview_lines.append(src)
        elif cell["cell_type"] == "code":
            # Keep only non-install lines, truncated
            lines = [l for l in src.split("\n") if not l.strip().startswith("!pip")]
            snippet = "\n".join(lines[:15])
            if snippet.strip():
                code_snippets.append(snippet)

    return {
        "title": title,
        "overview": "\n\n".join(overview_lines[:3]),
        "steps": steps,
        "code_snippets": code_snippets[:6],
        "exercises": exercises,
        "cell_count": len(nb["cells"]),
        "notebook_path": path,
    }


# ---------------------------------------------------------------------------
# LLM call — tries Ali first, then Azure
# ---------------------------------------------------------------------------

def call_llm(prompt: str) -> str:
    """Call LLM. Tries ali skill, falls back to azure skill."""
    skills_dir = Path(__file__).parent.parent / ".github" / "skills"

    # Try ali
    ali_script = skills_dir / "ali" / "scripts" / "llm.py"
    if ali_script.exists() and os.environ.get("ALIKEY"):
        result = subprocess.run(
            [sys.executable, str(ali_script), "--model", "qwen3-coder-plus", "--prompt", prompt],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()

    # Try azure
    azure_script = skills_dir / "azure" / "scripts" / "llm.py"
    if azure_script.exists() and os.environ.get("AZURE_API_KEY"):
        result = subprocess.run(
            [sys.executable, str(azure_script), "--model", "grok-4-1-fast-non-reasoning", "--prompt", prompt],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()

    raise RuntimeError(
        "No LLM available. Set ALIKEY (Alibaba DashScope) or AZURE_API_KEY (Azure AI Foundry)."
    )


def build_llm_prompt(content: dict) -> str:
    steps_text = "\n".join(f"- {s}" for s in content["steps"])
    code_text = "\n\n".join(f"```python\n{s}\n```" for s in content["code_snippets"])
    exercises_text = "\n".join(f"- {e}" for e in content["exercises"])

    return textwrap.dedent(f"""
    You are generating content for a beautiful excalidraw-style HTML explainer page for a Jupyter notebook.

    Notebook: {content['title']}
    Path: {content['notebook_path']}

    Overview:
    {content['overview']}

    Steps covered:
    {steps_text}

    Key code:
    {code_text}

    Exercises:
    {exercises_text}

    Generate a JSON object with this exact structure (no markdown, just raw JSON):
    {{
      "title": "short engaging title",
      "emoji": "single emoji representing the topic",
      "tagline": "one sentence hook explaining the notebook",
      "why": "2-3 sentences: why this topic matters, real-world applications",
      "what_you_learn": ["skill 1", "skill 2", "skill 3", "skill 4"],
      "steps": [
        {{"num": 1, "title": "Step title", "description": "what happens here", "color": "yellow"}},
        ...
      ],
      "key_concepts": [
        {{"term": "Term", "definition": "clear one-line definition"}},
        ...
      ],
      "prereqs": ["prereq 1", "prereq 2"],
      "time_estimate": "~X minutes",
      "difficulty": "Beginner|Intermediate|Advanced",
      "colab_url": "https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/{content['notebook_path']}"
    }}

    Use colors: yellow, blue, green, pink, purple, orange (rotating through steps).
    Be educational, enthusiastic, and clear. Avoid jargon without explanation.
    """).strip()


def parse_llm_json(raw: str) -> dict:
    """Extract JSON from LLM response (may have surrounding text)."""
    # Try direct parse first
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass
    # Find JSON block
    match = re.search(r'\{.*\}', raw, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError(f"No valid JSON found in LLM response:\n{raw[:500]}")


# ---------------------------------------------------------------------------
# HTML rendering
# ---------------------------------------------------------------------------

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} — Explainer</title>
<link href="https://fonts.googleapis.com/css2?family=Caveat:wght@400;600;700&family=Inter:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/roughjs@4.6.6/bundled/rough.min.js"></script>
<style>
  :root {{
    --bg: #faf9f6;
    --surface: #ffffff;
    --ink: #1a1a2e;
    --muted: #6b7280;
    --accent: #7c3aed;
    --accent2: #0ea5e9;
    --accent3: #10b981;
    --accent4: #f59e0b;
    --accent5: #ef4444;
    --border: #e5e7eb;
    --code-bg: #1e1e2e;
    --code-fg: #cdd6f4;
    --c-yellow: #fef9c3;
    --c-blue: #dbeafe;
    --c-green: #dcfce7;
    --c-pink: #fce7f3;
    --c-purple: #ede9fe;
    --c-orange: #ffedd5;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: 'Inter', sans-serif; background: var(--bg); color: var(--ink); line-height: 1.7; }}
  a {{ color: var(--accent); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}

  nav {{
    position: sticky; top: 0; z-index: 100;
    background: rgba(250,249,246,0.95); backdrop-filter: blur(8px);
    border-bottom: 1px solid var(--border);
    padding: 0.75rem 2rem; display: flex; align-items: center; gap: 2rem;
  }}
  nav .brand {{ font-family: 'Caveat', cursive; font-size: 1.4rem; font-weight: 700; color: var(--accent); }}
  .btn {{
    display: inline-flex; align-items: center; gap: 0.4rem;
    padding: 0.4rem 1rem; border-radius: 8px;
    font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: all 0.15s;
    text-decoration: none !important;
  }}
  .btn-primary {{ background: var(--accent); color: white; }}
  .btn-primary:hover {{ background: #6d28d9; transform: translateY(-1px); }}
  .btn-outline {{ border: 2px solid var(--ink); background: white; color: var(--ink); }}
  .btn-outline:hover {{ background: var(--ink); color: white; }}
  .btn-colab {{ background: #f9ab00; color: #1a1a2e; }}
  .btn-colab:hover {{ background: #e09800; transform: translateY(-1px); }}

  .hero {{
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
    color: white; padding: 5rem 2rem 3rem; text-align: center; position: relative; overflow: hidden;
  }}
  .hero-emoji {{ font-size: 4rem; margin-bottom: 1rem; }}
  .hero h1 {{ font-size: clamp(2rem, 5vw, 3.5rem); font-weight: 600; margin-bottom: 0.5rem; }}
  .hero h1 span {{ color: #a78bfa; }}
  .hero .tagline {{ font-size: 1.15rem; color: rgba(255,255,255,0.75); max-width: 600px; margin: 0 auto 2rem; }}
  .hero-pills {{ display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap; margin-bottom: 2rem; }}
  .pill {{
    background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2);
    color: white; padding: 0.35rem 0.9rem; border-radius: 9999px; font-size: 0.82rem;
  }}
  .hero-actions {{ display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap; }}

  .container {{ max-width: 900px; margin: 0 auto; padding: 0 1.5rem; }}

  .section {{ padding: 3rem 0; }}
  .section-title {{
    font-family: 'Caveat', cursive; font-size: 2rem; font-weight: 700;
    margin-bottom: 1.5rem; display: flex; align-items: center; gap: 0.5rem;
  }}

  .why-box {{
    background: var(--c-blue); border: 2.5px solid var(--ink);
    border-radius: 16px; padding: 2rem; position: relative;
  }}
  .why-box p {{ font-size: 1.05rem; line-height: 1.8; }}

  .learn-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 1rem; }}
  .learn-item {{
    background: white; border: 2px solid var(--ink); border-radius: 12px;
    padding: 1rem; text-align: center; font-size: 0.9rem; font-weight: 500;
    box-shadow: 3px 3px 0 var(--ink);
  }}
  .learn-item::before {{ content: "✓ "; color: var(--accent3); font-weight: 700; }}

  .steps-list {{ display: flex; flex-direction: column; gap: 1.5rem; }}
  .step-card {{
    display: grid; grid-template-columns: 60px 1fr; gap: 1.5rem;
    border: 2.5px solid var(--ink); border-radius: 16px; padding: 1.5rem;
    position: relative; overflow: hidden;
  }}
  .step-card.yellow {{ background: var(--c-yellow); }}
  .step-card.blue {{ background: var(--c-blue); }}
  .step-card.green {{ background: var(--c-green); }}
  .step-card.pink {{ background: var(--c-pink); }}
  .step-card.purple {{ background: var(--c-purple); }}
  .step-card.orange {{ background: var(--c-orange); }}
  .step-num {{
    width: 52px; height: 52px; background: var(--ink); color: white;
    border-radius: 50%; display: flex; align-items: center; justify-content: center;
    font-family: 'Caveat', cursive; font-size: 1.6rem; font-weight: 700; flex-shrink: 0;
  }}
  .step-card h3 {{ font-size: 1.2rem; margin-bottom: 0.4rem; }}
  .step-card p {{ color: #374151; font-size: 0.95rem; }}

  .concepts-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; }}
  .concept-card {{
    background: white; border: 2px solid var(--ink); border-radius: 12px;
    padding: 1.25rem; box-shadow: 3px 3px 0 #d1d5db;
  }}
  .concept-card .term {{
    font-family: 'JetBrains Mono', monospace; font-size: 0.9rem;
    font-weight: 600; color: var(--accent); margin-bottom: 0.4rem;
  }}
  .concept-card .def {{ font-size: 0.88rem; color: var(--muted); }}

  .meta-bar {{
    display: flex; gap: 2rem; flex-wrap: wrap; justify-content: center;
    background: white; border: 2px solid var(--border); border-radius: 16px;
    padding: 1.5rem; margin: 2rem 0;
  }}
  .meta-item {{ text-align: center; }}
  .meta-item .label {{ font-size: 0.75rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }}
  .meta-item .value {{ font-size: 1.1rem; font-weight: 600; margin-top: 0.2rem; }}

  .prereqs-list {{ display: flex; flex-wrap: wrap; gap: 0.6rem; }}
  .prereq-tag {{
    background: var(--c-orange); border: 2px solid var(--ink);
    border-radius: 8px; padding: 0.3rem 0.75rem; font-size: 0.85rem; font-weight: 500;
  }}

  .cta-box {{
    background: linear-gradient(135deg, #7c3aed, #0ea5e9);
    border-radius: 20px; padding: 3rem 2rem; text-align: center; color: white; margin: 3rem 0;
  }}
  .cta-box h2 {{ font-family: 'Caveat', cursive; font-size: 2rem; margin-bottom: 0.5rem; }}
  .cta-box p {{ opacity: 0.85; margin-bottom: 1.5rem; }}
  .cta-actions {{ display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap; }}

  footer {{
    border-top: 1px solid var(--border); padding: 2rem; text-align: center;
    color: var(--muted); font-size: 0.85rem;
  }}
  footer a {{ color: var(--muted); }}
</style>
</head>
<body>

<nav>
  <span class="brand">🦃 trainingdemo</span>
  <div style="margin-left:auto;display:flex;gap:0.75rem">
    <a href="https://github.com/Copilotclaw/trainingdemo" class="btn btn-outline">GitHub</a>
    <a href="{colab_url}" target="_blank" class="btn btn-colab">🚀 Open in Colab</a>
  </div>
</nav>

<section class="hero">
  <div class="hero-emoji">{emoji}</div>
  <h1>{title_html}</h1>
  <p class="tagline">{tagline}</p>
  <div class="hero-pills">
    <span class="pill">⏱ {time_estimate}</span>
    <span class="pill">📊 {difficulty}</span>
    <span class="pill">📓 Jupyter Notebook</span>
  </div>
  <div class="hero-actions">
    <a href="{colab_url}" target="_blank" class="btn btn-colab">🚀 Open in Colab</a>
    <a href="https://github.com/Copilotclaw/trainingdemo" class="btn btn-outline" style="color:white;border-color:rgba(255,255,255,0.4)">📁 View Source</a>
  </div>
</section>

<main class="container">

  <!-- Meta bar -->
  <div class="meta-bar">
    <div class="meta-item"><div class="label">Time</div><div class="value">⏱ {time_estimate}</div></div>
    <div class="meta-item"><div class="label">Difficulty</div><div class="value">{difficulty}</div></div>
    <div class="meta-item"><div class="label">Platform</div><div class="value">Google Colab</div></div>
    <div class="meta-item"><div class="label">Cost</div><div class="value">Free 🎉</div></div>
  </div>

  <!-- Why -->
  <div class="section">
    <h2 class="section-title">💡 Why this matters</h2>
    <div class="why-box">
      <p>{why}</p>
    </div>
  </div>

  <!-- What you'll learn -->
  <div class="section">
    <h2 class="section-title">🎯 What you'll learn</h2>
    <div class="learn-grid">
      {learn_items}
    </div>
  </div>

  <!-- Prerequisites -->
  {prereqs_section}

  <!-- Steps -->
  <div class="section">
    <h2 class="section-title">🗺️ What we do — step by step</h2>
    <div class="steps-list">
      {step_cards}
    </div>
  </div>

  <!-- Key concepts -->
  {concepts_section}

  <!-- CTA -->
  <div class="cta-box">
    <h2>Ready to dive in?</h2>
    <p>No install needed — runs entirely in your browser via Google Colab.</p>
    <div class="cta-actions">
      <a href="{colab_url}" target="_blank" class="btn btn-colab" style="font-size:1rem;padding:0.75rem 1.75rem">
        🚀 Open in Colab — it's free!
      </a>
      <a href="https://github.com/Copilotclaw/trainingdemo" class="btn" style="background:rgba(255,255,255,0.15);color:white;font-size:1rem;padding:0.75rem 1.75rem">
        📁 Browse All Notebooks
      </a>
    </div>
  </div>

</main>

<footer>
  <p>Generated by <a href="https://github.com/Copilotclaw/copilotclaw">🦃 Crunch</a> — AI agent @ Copilotclaw &nbsp;·&nbsp;
  <a href="https://github.com/Copilotclaw/trainingdemo">trainingdemo</a></p>
</footer>

</body>
</html>
"""


def render_html(data: dict) -> str:
    # Title with last word highlighted in accent
    words = data["title"].split()
    title_html = " ".join(words[:-1]) + f' <span>{words[-1]}</span>' if len(words) > 1 else data["title"]

    learn_items = "\n".join(
        f'<div class="learn-item">{item}</div>'
        for item in data.get("what_you_learn", [])
    )

    step_cards = "\n".join(
        f'''<div class="step-card {s.get('color', 'blue')}">
  <div class="step-num">{s['num']}</div>
  <div>
    <h3>{s['title']}</h3>
    <p>{s['description']}</p>
  </div>
</div>'''
        for s in data.get("steps", [])
    )

    prereqs = data.get("prereqs", [])
    prereqs_section = ""
    if prereqs:
        tags = "\n".join(f'<span class="prereq-tag">{p}</span>' for p in prereqs)
        prereqs_section = f'''<div class="section">
  <h2 class="section-title">📋 Prerequisites</h2>
  <div class="prereqs-list">{tags}</div>
</div>'''

    concepts = data.get("key_concepts", [])
    concepts_section = ""
    if concepts:
        cards = "\n".join(
            f'<div class="concept-card"><div class="term">{c["term"]}</div><div class="def">{c["definition"]}</div></div>'
            for c in concepts
        )
        concepts_section = f'''<div class="section">
  <h2 class="section-title">🔑 Key concepts</h2>
  <div class="concepts-grid">{cards}</div>
</div>'''

    return HTML_TEMPLATE.format(
        title=data["title"],
        title_html=title_html,
        emoji=data.get("emoji", "📓"),
        tagline=data.get("tagline", ""),
        why=data.get("why", ""),
        time_estimate=data.get("time_estimate", "~30 minutes"),
        difficulty=data.get("difficulty", "Beginner"),
        colab_url=data.get("colab_url", "#"),
        learn_items=learn_items,
        prereqs_section=prereqs_section,
        step_cards=step_cards,
        concepts_section=concepts_section,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate excalidraw-style HTML explainer from a Jupyter notebook")
    parser.add_argument("notebook", help="Path to the .ipynb file")
    parser.add_argument("--output", "-o", help="Output HTML path (default: {notebook-stem}.html)")
    parser.add_argument("--no-llm", action="store_true", help="Skip LLM, use notebook metadata only (for testing)")
    args = parser.parse_args()

    nb_path = Path(args.notebook)
    if not nb_path.exists():
        sys.exit(f"Error: {nb_path} not found")

    output_path = Path(args.output) if args.output else nb_path.with_suffix(".html").with_stem(nb_path.stem + "-explainer")
    # Special case: if notebook is simple-rag-demo.ipynb and no explicit output, write to explainer.html
    if nb_path.stem == "simple-rag-demo" and not args.output:
        output_path = nb_path.parent / "explainer.html"

    print(f"📖 Extracting content from {nb_path}...")
    content = extract_notebook_content(str(nb_path))
    print(f"   Title: {content['title']}")
    print(f"   Steps: {len(content['steps'])}")
    print(f"   Code snippets: {len(content['code_snippets'])}")

    if args.no_llm:
        # Minimal data without LLM
        data = {
            "title": content["title"],
            "emoji": "📓",
            "tagline": f"A hands-on notebook covering {content['title']}",
            "why": "This notebook provides practical experience with key concepts.",
            "what_you_learn": [s.lstrip("## ").split("\n")[0] for s in content["steps"][:4]],
            "steps": [
                {"num": i+1, "title": s.lstrip("## ").split("\n")[0], "description": "", "color": ["yellow","blue","green","pink","purple","orange"][i % 6]}
                for i, s in enumerate(content["steps"])
            ],
            "key_concepts": [],
            "prereqs": ["Python basics"],
            "time_estimate": "~30 minutes",
            "difficulty": "Beginner",
            "colab_url": f"https://colab.research.google.com/github/Copilotclaw/trainingdemo/blob/main/{nb_path.name}",
        }
    else:
        print("🤖 Calling LLM to generate description...")
        prompt = build_llm_prompt(content)
        raw = call_llm(prompt)
        print("   LLM responded. Parsing JSON...")
        data = parse_llm_json(raw)

    print(f"✨ Rendering HTML...")
    html = render_html(data)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html, encoding="utf-8")
    print(f"✅ Written to {output_path} ({len(html):,} bytes)")


if __name__ == "__main__":
    main()
