#!/usr/bin/env python3
"""
Extract the last N comments verbatim from a .full.md issue dump.

Usage:
    python3 recent-comments.py state/issues/123.full.md [-n 5]

Output:
    Markdown block with last N comments verbatim, preceded by a note
    about how many older comments are covered by the running summary.
"""
import sys
import re
import argparse


def main():
    parser = argparse.ArgumentParser(description="Extract last N comments from .full.md")
    parser.add_argument("full_file", help="Path to .full.md issue dump")
    parser.add_argument("-n", "--count", type=int, default=5,
                        help="Number of recent comments to include verbatim (default: 5)")
    args = parser.parse_args()

    try:
        content = open(args.full_file, encoding="utf-8").read()
    except FileNotFoundError:
        sys.exit(0)

    # Locate the comments section
    comments_match = re.search(r'\n## Comments \(\d+\)', content)
    if not comments_match:
        sys.exit(0)

    comments_section = content[comments_match.start():]

    # Split into individual comments (each starts with "### Comment N —")
    parts = re.split(r'\n(?=### Comment \d+)', comments_section)
    comment_parts = [p.strip() for p in parts if re.match(r'### Comment \d+', p.strip())]

    if not comment_parts:
        sys.exit(0)

    total = len(comment_parts)
    recent = comment_parts[-args.count:]
    older_count = total - len(recent)

    lines = []
    if older_count > 0:
        noun = "comment" if older_count == 1 else "comments"
        lines.append(
            f"*({older_count} older {noun} omitted — covered by the running summary above. "
            f"Last {len(recent)} shown verbatim below.)*\n"
        )
    lines.append("\n\n".join(recent))

    print("\n".join(lines))


if __name__ == "__main__":
    main()
