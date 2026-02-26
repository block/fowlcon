#!/usr/bin/env bash
#
# check-tree-quality.sh -- Validate structural quality of a review-tree.md file.
#
# Usage: check-tree-quality.sh <tree-file> <file-list> [--max-top-level N]
#
# Arguments:
#   tree-file       Path to the review-tree.md file
#   file-list       Path to a text file with one file path per line (from PR diff)
#   --max-top-level N  Maximum allowed top-level nodes (default: 7, Miller's 7±2)
#
# Checks performed:
#   1. HEAD SHA present in header
#   2. Revision field present in header
#   3. Description Verification section exists
#   4. Top-level node count <= threshold
#   5. Every file in the diff file list appears in at least one tree node
#   6. Variation nodes have at least one {repeat} child (warning, not failure)
#
# Output: One line per check (PASS/FAIL/WARN + reason). Exit 0 if all pass,
# exit 1 if any check fails. Warnings do not cause failure.
#
# Exit codes:
#   0 -- all checks pass (warnings are OK)
#   1 -- at least one check failed, or invalid arguments

set -euo pipefail

# --- Parse arguments ---

if [ $# -lt 2 ]; then
  echo "Usage: check-tree-quality.sh <tree-file> <file-list> [--max-top-level N]" >&2
  exit 1
fi

TREE_FILE="$1"
FILE_LIST="$2"
shift 2

MAX_TOP_LEVEL=7

while [ $# -gt 0 ]; do
  case "$1" in
    --max-top-level) MAX_TOP_LEVEL="$2"; shift 2 ;;
    *) echo "Error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# --- Input validation ---

if [ ! -f "$TREE_FILE" ]; then
  echo "Error: tree file not found: $TREE_FILE" >&2
  exit 1
fi

if [ ! -f "$FILE_LIST" ]; then
  echo "Error: file list not found: $FILE_LIST" >&2
  exit 1
fi

# --- Run checks ---

FAILED=0

# Check 1: HEAD SHA
if grep -q -- '| HEAD' "$TREE_FILE"; then
  echo "PASS: HEAD SHA present"
else
  echo "FAIL: HEAD SHA missing from header"
  FAILED=1
fi

# Check 2: Revision field
if grep -q -- '| Revision' "$TREE_FILE"; then
  echo "PASS: Revision field present"
else
  echo "FAIL: Revision field missing from header"
  FAILED=1
fi

# Check 3: Description Verification section
if grep -q -- '^## Description Verification' "$TREE_FILE"; then
  echo "PASS: Description Verification section present"
else
  echo "FAIL: Description Verification section missing"
  FAILED=1
fi

# Check 4: Top-level node count
TOP_LEVEL=$(grep -cE '^- \[(pending|reviewed|accepted)\] [0-9]' "$TREE_FILE" || true)
if [ "$TOP_LEVEL" -le "$MAX_TOP_LEVEL" ]; then
  echo "PASS: top-level concepts: $TOP_LEVEL (max: $MAX_TOP_LEVEL)"
else
  echo "FAIL: top-level concepts: $TOP_LEVEL exceeds max of $MAX_TOP_LEVEL"
  FAILED=1
fi

# Check 5: File coverage -- every diff file appears in at least one node
# Extract all file paths from the tree (strip line ranges and change counts)
TREE_FILES=$(grep -E '^\s+- .+ L[0-9]' "$TREE_FILE" | sed -E 's/^[[:space:]]+- //' | sed -E 's/ L[0-9]+.*//' | sort -u || true)

UNMAPPED=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! echo "$TREE_FILES" | grep -qxF -- "$file"; then
    UNMAPPED="${UNMAPPED}${file}\n"
  fi
done < "$FILE_LIST"

if [ -z "$UNMAPPED" ]; then
  echo "PASS: file coverage complete"
else
  echo "FAIL: unmapped files in diff:"
  printf "  %b" "$UNMAPPED"
  FAILED=1
fi

# Check 6: Variation structure (warning only)
# For each {variation} node, check if any child has {repeat}
# Pattern matches {variation}, {variation comment}, etc.
VARIATION_LINES=$(grep -nE '\{[^}]*variation' "$TREE_FILE" || true)
if [ -n "$VARIATION_LINES" ]; then
  while IFS=: read -r line_num line_text; do
    # Get the indentation level of this variation node
    # Assumes 2-space indent per level (per format spec)
    # wc -c includes trailing newline, subtract 1
    indent=$(( $(echo "$line_text" | sed -E 's/[^ ].*//' | wc -c) - 1 ))
    child_indent=$((indent + 2))
    # Look for {repeat} in lines after this one at deeper indentation
    has_repeat=$(awk -v start="$line_num" -v ci="$child_indent" '
      NR > start && /\{[^}]*repeat/ { print "yes"; exit }
      NR > start && /^[[:space:]]*- \[/ {
        match($0, /[^ ]/); cur = RSTART - 1
        if (cur < ci) exit
      }
    ' "$TREE_FILE" || true)
    if [ -z "$has_repeat" ]; then
      node_id=$(echo "$line_text" | grep -oE '\] [0-9]+(\.[0-9]+)*\.' | sed -E 's/\] //; s/\.$//')
      echo "WARN: variation node $node_id has no {repeat} children"
    fi
  done <<< "$VARIATION_LINES"
fi

# --- Exit ---

if [ "$FAILED" -eq 1 ]; then
  exit 1
fi
