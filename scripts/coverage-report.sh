#!/usr/bin/env bash
#
# coverage-report.sh -- Generate a coverage summary from a review-tree.md file.
#
# Usage: coverage-report.sh <tree-file>
#
# Output: Structured markdown text suitable for the orchestrator to present
# to the customer. The output format is a contract -- the orchestrator parses
# these field names and section headers.
#
# Output format:
#   ## Status
#     pending: <N>
#     reviewed: <N>
#     accepted: <N>
#     total: <N>
#     decided: <N>/<total> (<pct>%)
#     with comments: <N>
#     examined in detail: <N>
#     pattern-trusted: <N>
#     top-level concepts: <N>
#   ## Files
#     files in diff: <N>
#     files mapped: <N>
#     unmapped: <text>
#   ## Pending  (only if pending > 0)
#     Pending nodes:
#     <list>
#
# Exit codes:
#   0 -- success
#   1 -- invalid arguments or file not found

set -euo pipefail

# --- Input validation ---

if [ $# -lt 1 ]; then
  echo "Usage: coverage-report.sh <tree-file>" >&2
  exit 1
fi

TREE_FILE="$1"

if [ ! -f "$TREE_FILE" ]; then
  echo "Error: file not found: $TREE_FILE" >&2
  exit 1
fi

# --- Count nodes by status ---
# Pattern includes [0-9] after status to avoid matching status-like text in context blocks

PENDING=$(grep -cE '^\s*- \[pending\] [0-9]' "$TREE_FILE" || true)
REVIEWED=$(grep -cE '^\s*- \[reviewed\] [0-9]' "$TREE_FILE" || true)
ACCEPTED=$(grep -cE '^\s*- \[accepted\] [0-9]' "$TREE_FILE" || true)
TOTAL=$((PENDING + REVIEWED + ACCEPTED))

# --- Progress ---

DECIDED=$((REVIEWED + ACCEPTED))
if [ "$TOTAL" -gt 0 ]; then
  PCT=$((DECIDED * 100 / TOTAL))
else
  PCT=0
fi

# --- Count nodes with comments ---
# Pattern matches "comment" inside flag braces only, not in titles or context

WITH_COMMENTS=$(grep -cE '\{[^}]*comment\}' "$TREE_FILE" || true)

# --- Count top-level concepts ---

TOP_LEVEL=$(grep -cE '^- \[(pending|reviewed|accepted)\] [0-9]' "$TREE_FILE" || true)

# --- File coverage from tree's Coverage section ---

TOTAL_FILES=$(grep 'Total files in diff:' "$TREE_FILE" | grep -oE '[0-9]+' || true)
MAPPED_FILES=$(grep 'Files mapped to tree:' "$TREE_FILE" | grep -oE '[0-9]+' || true)
UNMAPPED=$(grep 'Unmapped files:' "$TREE_FILE" | sed 's/.*: //' || true)

# --- List pending nodes ---

PENDING_LIST=$(grep -E '^\s*- \[pending\] [0-9]' "$TREE_FILE" | sed -E 's/^[[:space:]]*- \[pending\] /  /' || true)

# --- Output report ---

echo "## Status"
echo ""
echo "  pending: $PENDING"
echo "  reviewed: $REVIEWED"
echo "  accepted: $ACCEPTED"
echo "  total: $TOTAL"
echo "  decided: $DECIDED/$TOTAL ($PCT%)"
echo "  with comments: $WITH_COMMENTS"
echo ""
echo "  examined in detail: $REVIEWED"
echo "  pattern-trusted: $ACCEPTED"
echo "  top-level concepts: $TOP_LEVEL"

if [ -n "$TOTAL_FILES" ]; then
  echo ""
  echo "## Files"
  echo ""
  echo "  files in diff: $TOTAL_FILES"
  echo "  files mapped: $MAPPED_FILES"
  echo "  unmapped: $UNMAPPED"
fi

if [ "$PENDING" -gt 0 ]; then
  echo ""
  echo "## Pending"
  echo ""
  echo "  Pending nodes:"
  echo "$PENDING_LIST"
fi
