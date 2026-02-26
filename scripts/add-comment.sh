#!/usr/bin/env bash
#
# add-comment.sh -- Append a comment to a review-comments.md file.
#
# Usage: add-comment.sh <comments-file> [options]
#
# Required:
#   <comments-file>       Path to the review-comments.md file
#   --tree <tree-file>    Path to the review-tree.md file (for tree_rev)
#   --node <id>           Node ID (dot-separated digits or "root")
#   --type <type>         One of: inline, top-level
#   --text <body>         Comment body text
#
# Required for inline comments:
#   --file <path>         File path relative to repo root
#   --lines <start-end>   Line range (e.g., "19-40")
#
# Optional:
#   --side <side>         One of: right, left (default: right)
#   --source <source>     Comment source (default: reviewer)
#
# Behavior:
#   - Finds highest existing C<N> ID, assigns C<N+1>
#   - Validates all inputs including body content restrictions
#   - Reads tree Revision from the tree file for tree_rev field
#   - Writes atomically: full file to temp, then mv
#
# Content restrictions enforced:
#   - Body must not contain "### C" + digit at start of line (delimiter corruption)
#   - Body must not contain null bytes

set -euo pipefail

# --- Parse arguments ---

if [ $# -lt 1 ]; then
  echo "Usage: add-comment.sh <comments-file> --tree <file> --node <id> --type <type> --text <body> [--file <path>] [--lines <range>] [--side <side>] [--source <source>]" >&2
  exit 1
fi

COMMENTS_FILE="$1"
shift

TREE_FILE=""
NODE_ID=""
TYPE=""
TEXT=""
FILE=""
LINES=""
SIDE=""
SOURCE="reviewer"

while [ $# -gt 0 ]; do
  case "$1" in
    --tree)   TREE_FILE="$2"; shift 2 ;;
    --node)   NODE_ID="$2"; shift 2 ;;
    --type)   TYPE="$2"; shift 2 ;;
    --text)   TEXT="$2"; shift 2 ;;
    --file)   FILE="$2"; shift 2 ;;
    --lines)  LINES="$2"; shift 2 ;;
    --side)   SIDE="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    *)
      echo "Error: unknown option '$1'" >&2
      exit 1
      ;;
  esac
done

# --- Input validation ---

if [ ! -f "$COMMENTS_FILE" ]; then
  echo "Error: comments file not found: $COMMENTS_FILE" >&2
  exit 1
fi

if [ -z "$TREE_FILE" ] || [ ! -f "$TREE_FILE" ]; then
  echo "Error: tree file not found: $TREE_FILE" >&2
  exit 1
fi

if [ -z "$NODE_ID" ]; then
  echo "Error: --node is required" >&2
  exit 1
fi

# Validate node ID format (digits and dots, or "root")
if [ "$NODE_ID" != "root" ]; then
  if ! [[ "$NODE_ID" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "Error: invalid node ID '$NODE_ID'. Must be dot-separated digits or 'root'" >&2
    exit 1
  fi
fi

if [ -z "$TYPE" ]; then
  echo "Error: --type is required" >&2
  exit 1
fi

case "$TYPE" in
  inline|top-level) ;;
  *)
    echo "Error: invalid type '$TYPE'. Must be: inline, top-level" >&2
    exit 1
    ;;
esac

if [ -z "$TEXT" ]; then
  echo "Error: --text is required" >&2
  exit 1
fi

# Inline comments require file, lines; side defaults to right
if [ "$TYPE" = "inline" ]; then
  if [ -z "$FILE" ]; then
    echo "Error: --file is required for inline comments" >&2
    exit 1
  fi
  if [ -z "$LINES" ]; then
    echo "Error: --lines is required for inline comments" >&2
    exit 1
  fi
  if ! [[ "$LINES" =~ ^[0-9]+-[0-9]+$ ]]; then
    echo "Error: invalid lines format '$LINES'. Must be <start>-<end> (e.g., 19-40)" >&2
    exit 1
  fi
  if [ -z "$SIDE" ]; then
    SIDE="right"
  fi
  case "$SIDE" in
    right|left) ;;
    *)
      echo "Error: invalid side '$SIDE'. Must be: right, left" >&2
      exit 1
      ;;
  esac
fi

# --- Content validation ---

# Check for delimiter pattern in body (handle multi-line text)
if printf '%s\n' "$TEXT" | grep -qE '^### C[0-9]'; then
  echo "Error: comment body contains delimiter pattern '### C<digit>' at start of line. This would corrupt the file." >&2
  exit 1
fi

# Check for null bytes
if printf '%s' "$TEXT" | grep -qP '\x00' 2>/dev/null; then
  echo "Error: comment body contains null bytes" >&2
  exit 1
elif [ "$(printf '%s' "$TEXT" | wc -c)" != "$(printf '%s' "$TEXT" | tr -d '\0' | wc -c)" ]; then
  echo "Error: comment body contains null bytes" >&2
  exit 1
fi

# --- Validate node exists in tree ---

if [ "$NODE_ID" != "root" ]; then
  ESCAPED_NODE=$(echo "$NODE_ID" | sed 's/\./\\./g')
  if ! grep -qE -- "^[[:space:]]*- \[.*\] ${ESCAPED_NODE}\. " "$TREE_FILE"; then
    echo "Error: node '$NODE_ID' not found in tree" >&2
    exit 1
  fi
fi

# --- Read tree revision ---

TREE_REV=$(grep -- '| Revision' "$TREE_FILE" | awk -F'|' '{print $3}' | tr -d ' ')
if [ -z "$TREE_REV" ]; then
  echo "Error: could not read Revision from tree file" >&2
  exit 1
fi

# --- Find next comment ID ---

HIGHEST=$(grep -oE '^### C([0-9]+)' "$COMMENTS_FILE" | sed 's/### C//' | sort -n | tail -1 || true)
if [ -z "$HIGHEST" ]; then
  NEXT_ID=1
else
  NEXT_ID=$((HIGHEST + 1))
fi

# --- Build comment block ---

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

COMMENT_BLOCK="
### C${NEXT_ID}
node: ${NODE_ID}
type: ${TYPE}
status: active
source: ${SOURCE}"

if [ "$TYPE" = "inline" ]; then
  COMMENT_BLOCK="${COMMENT_BLOCK}
file: ${FILE}
lines: L${LINES}
side: ${SIDE}"
fi

COMMENT_BLOCK="${COMMENT_BLOCK}
tree_rev: ${TREE_REV}
created: ${TIMESTAMP}

${TEXT}"

# --- Atomic write: comments file ---

TMPFILE="${COMMENTS_FILE}.tmp"
TREE_TMPFILE="${TREE_FILE}.tmp"
trap 'rm -f "$TMPFILE" "$TREE_TMPFILE"' EXIT

cat "$COMMENTS_FILE" > "$TMPFILE"
echo "$COMMENT_BLOCK" >> "$TMPFILE"
mv "$TMPFILE" "$COMMENTS_FILE"

# --- Add {comment} flag to tree node (if not "root" and not already flagged) ---

if [ "$NODE_ID" != "root" ]; then
  ESCAPED_ID=$(echo "$NODE_ID" | sed 's/\./\\./g')
  NODE_LINE=$(grep -E -- "^[[:space:]]*- \[.*\] ${ESCAPED_ID}\. " "$TREE_FILE" || true)
  if [ -n "$NODE_LINE" ] && [[ "$NODE_LINE" != *"comment}"* ]]; then
    if [[ "$NODE_LINE" == *"{"* ]]; then
      # Node has existing flags -- add comment before closing brace
      awk -v id="$ESCAPED_ID" '
$0 ~ "^[[:space:]]*- \\[.*\\] " id "\\. " && /\{/ { sub(/\}/, " comment}") }
{ print }
' "$TREE_FILE" > "$TREE_TMPFILE" && mv "$TREE_TMPFILE" "$TREE_FILE"
    else
      # Node has no flags -- append {comment}
      awk -v id="$ESCAPED_ID" '
$0 ~ "^[[:space:]]*- \\[.*\\] " id "\\. " && !/\{/ { $0 = $0 " {comment}" }
{ print }
' "$TREE_FILE" > "$TREE_TMPFILE" && mv "$TREE_TMPFILE" "$TREE_FILE"
    fi
    # Update tree's Updated timestamp
    TIMESTAMP_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    sed -E "s/^(\| Updated[[:space:]]*\|[[:space:]]*).*(\|)/\1${TIMESTAMP_NOW} \2/" \
      "$TREE_FILE" > "$TREE_TMPFILE" && mv "$TREE_TMPFILE" "$TREE_FILE"
  fi
fi
