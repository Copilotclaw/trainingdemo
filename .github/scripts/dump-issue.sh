#!/usr/bin/env bash
# dump-issue.sh — Dump a GitHub issue thread to a full markdown file
# Usage: dump-issue.sh <issue_number> [output_file]
# Output goes to <output_file> or state/issues/<N>.full.md by default
set -euo pipefail

ISSUE_NUMBER="${1:?Usage: dump-issue.sh <issue_number> [output_file]}"
OUTPUT="${2:-state/issues/${ISSUE_NUMBER}.full.md}"

mkdir -p "$(dirname "$OUTPUT")"

# Fetch full issue data including comments
DATA=$(gh issue view "$ISSUE_NUMBER" --comments \
  --json number,title,state,author,body,labels,createdAt,updatedAt,comments,url)

jq -r '
  "# Issue #\(.number): \(.title)\n" +
  "\n**URL**: \(.url)" +
  "\n**State**: \(.state)" +
  "\n**Author**: \(.author.login)" +
  "\n**Created**: \(.createdAt)" +
  "\n**Updated**: \(.updatedAt)" +
  "\n**Labels**: \([ .labels[].name ] | if length > 0 then join(", ") else "none" end)" +
  "\n\n---\n\n## Original Post\n\n\(.body // "_(empty)_")\n\n---\n\n## Comments (\(.comments | length))\n\n" +
  (.comments | to_entries | map(
    "### Comment \(.key + 1) — \(.value.author.login) (\(.value.createdAt))\n\n" +
    (.value.body // "_(empty)_") + "\n\n"
  ) | add // "_(no comments)_\n")
' <<< "$DATA" > "$OUTPUT"

echo "✅ Wrote $(wc -l < "$OUTPUT") lines to $OUTPUT"
