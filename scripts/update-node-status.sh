#!/usr/bin/env bash
#
# update-node-status.sh -- Update a node's status in a review-tree.md file.
#
# Usage: update-node-status.sh <tree-file> <node-id> <new-status>
#
# Arguments:
#   tree-file   Path to the review-tree.md file
#   node-id     Dot-separated node ID (e.g., "1.1", "2.1.5", "3")
#   new-status  One of: pending, reviewed, accepted
#
# Behavior:
#   - Finds the node by ID using regex (dots escaped for exact match)
#   - Replaces the status keyword between brackets
#   - Updates the "Updated" timestamp in the header
#   - Writes atomically: temp file + mv
#   - Validates inputs, exits non-zero on error
#
# The script does NOT modify flags, title, or any other part of the node line.

set -euo pipefail

# --- Input validation ---

if [ $# -lt 3 ]; then
  echo "Usage: update-node-status.sh <tree-file> <node-id> <new-status>" >&2
  exit 1
fi

TREE_FILE="$1"
NODE_ID="$2"
NEW_STATUS="$3"

if [ ! -f "$TREE_FILE" ]; then
  echo "Error: file not found: $TREE_FILE" >&2
  exit 1
fi

if [ -z "$NEW_STATUS" ]; then
  echo "Error: status cannot be empty" >&2
  exit 1
fi

# Validate node ID format (digits and dots only -- prevents regex injection)
if ! [[ "$NODE_ID" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Error: invalid node ID '$NODE_ID'. Must be dot-separated digits (e.g., 1.1.2)" >&2
  exit 1
fi

case "$NEW_STATUS" in
  pending|reviewed|accepted) ;;
  *)
    echo "Error: invalid status '$NEW_STATUS'. Must be: pending, reviewed, accepted" >&2
    exit 1
    ;;
esac

# --- Build regex ---

# Escape dots in the node ID for regex matching
ESCAPED_ID=$(echo "$NODE_ID" | sed 's/\./\\./g')

# The node line pattern: optional whitespace, "- [status] <id>. "
# The trailing ". " after the ID prevents prefix matching (2.1 won't match 2.1.1)
NODE_PATTERN="^([[:space:]]*- \[)(pending|reviewed|accepted)(\] ${ESCAPED_ID}\. )"

# Verify the node exists in the file
if ! grep -qE -- "$NODE_PATTERN" "$TREE_FILE"; then
  echo "Error: node '$NODE_ID' not found in $TREE_FILE" >&2
  exit 1
fi

# --- Update status + timestamp in one pipeline ---

TMPFILE="${TREE_FILE}.tmp"
trap 'rm -f "$TMPFILE"' EXIT
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

sed -E "s/${NODE_PATTERN}/\1${NEW_STATUS}\3/" "$TREE_FILE" \
  | sed -E "s/^(\| Updated[[:space:]]*\|[[:space:]]*).*(\|)/\1${TIMESTAMP} \2/" \
  > "$TMPFILE"

# --- Atomic write ---

mv "$TMPFILE" "$TREE_FILE"
