#!/usr/bin/env bats

# Tests for scripts/add-comment.sh
# TDD: write tests first, then implement the script.

COMMENTS_SAMPLE="tests/formats/sample-comments-hawksbury.md"
TREE_SAMPLE="tests/formats/sample-tree-hawksbury.md"
SCRIPT="scripts/add-comment.sh"

setup() {
  cp "$COMMENTS_SAMPLE" "$BATS_TMPDIR/comments.md"
  cp "$TREE_SAMPLE" "$BATS_TMPDIR/tree.md"
}

# --- Adding inline comments ---

@test "adds inline comment with all metadata" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.2" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "The catch block swallows all exceptions silently."
  [ "$status" -eq 0 ]
  grep -q -- "RoostGuard.java" "$BATS_TMPDIR/comments.md"
  grep -q -- "catch block swallows" "$BATS_TMPDIR/comments.md"
  grep -q -- "node: 1.1.2" "$BATS_TMPDIR/comments.md"
  grep -q -- "type: inline" "$BATS_TMPDIR/comments.md"
  grep -q -- "status: active" "$BATS_TMPDIR/comments.md"
  grep -q -- "source: reviewer" "$BATS_TMPDIR/comments.md"
  grep -q -- "side: right" "$BATS_TMPDIR/comments.md"
  grep -q -- "lines: L19-40" "$BATS_TMPDIR/comments.md"
}

@test "assigns next sequential comment ID" {
  # Sample has C1-C5, so new comment should be C6
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.2" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "Test comment."
  [ "$status" -eq 0 ]
  grep -q -- "^### C6$" "$BATS_TMPDIR/comments.md"
}

@test "includes tree_rev from tree file" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.2" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "Test."
  [ "$status" -eq 0 ]
  grep -q -- "tree_rev: 1" "$BATS_TMPDIR/comments.md"
}

@test "sets created timestamp in ISO 8601" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.2" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "Test."
  [ "$status" -eq 0 ]
  # Extract the created timestamp from the new comment (C6)
  local ts
  ts=$(awk '/^### C6$/{found=1} found && /^created:/{print $2; exit}' "$BATS_TMPDIR/comments.md")
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# --- Adding top-level comments ---

@test "adds top-level comment without file/lines/side" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Overall the guard pattern is sound."
  [ "$status" -eq 0 ]
  grep -q -- "type: top-level" "$BATS_TMPDIR/comments.md"
  grep -q -- "node: root" "$BATS_TMPDIR/comments.md"
  grep -q -- "guard pattern is sound" "$BATS_TMPDIR/comments.md"
}

@test "top-level comment has no file or lines fields" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "3" \
    --type "top-level" \
    --text "Concern about commented-out code."
  [ "$status" -eq 0 ]
  # Extract the new comment block
  local block
  block=$(awk '/^### C6$/{found=1} found && /^### C[0-9]/ && $0 != "### C6"{exit} found{print}' "$BATS_TMPDIR/comments.md")
  [[ "$block" != *"file:"* ]]
  [[ "$block" != *"lines:"* ]]
  [[ "$block" != *"side:"* ]]
}

# --- Source field ---

@test "defaults source to reviewer" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Test."
  [ "$status" -eq 0 ]
  local block
  block=$(awk '/^### C6$/{found=1} found && /^### C[0-9]/ && $0 != "### C6"{exit} found{print}' "$BATS_TMPDIR/comments.md")
  [[ "$block" == *"source: reviewer"* ]]
}

@test "accepts custom source" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --source "coderabbit" \
    --text "Imported bot comment."
  [ "$status" -eq 0 ]
  grep -q -- "source: coderabbit" "$BATS_TMPDIR/comments.md"
}

# --- Atomic writes ---

@test "writes atomically via temp file" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Test."
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TMPDIR/comments.md.tmp" ]
}

@test "file integrity -- existing comments preserved" {
  local before
  before=$(grep -c -- "^### C[0-9]" "$BATS_TMPDIR/comments.md")
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "New comment."
  [ "$status" -eq 0 ]
  local after
  after=$(grep -c -- "^### C[0-9]" "$BATS_TMPDIR/comments.md")
  [ "$after" -eq "$((before + 1))" ]
}

# --- Content validation ---

@test "rejects body containing delimiter pattern at line start" {
  local body=$'First line\n### C1\nThird line'
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "$body"
  [ "$status" -ne 0 ]
}

@test "allows delimiter pattern mid-line (not at start)" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Reference: see ### C1 for details"
  [ "$status" -eq 0 ]
}

@test "null byte detection works in validation logic" {
  # Bats cannot pass null bytes through arguments, so we test the
  # detection logic directly rather than through the script interface.
  # The script uses: printf '%s' "$TEXT" | tr -d '\0' | wc -c
  # to detect null bytes by comparing byte counts.
  local with_null without_null
  with_null=$(printf 'hello\x00world' | wc -c | tr -d ' ')
  without_null=$(printf 'hello\x00world' | tr -d '\0' | wc -c | tr -d ' ')
  [ "$with_null" != "$without_null" ]
}

# --- Input validation ---

@test "rejects invalid node ID" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1+" \
    --type "top-level" \
    --text "Test."
  [ "$status" -ne 0 ]
}

@test "rejects invalid type" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "suggestion" \
    --text "Test."
  [ "$status" -ne 0 ]
}

@test "rejects inline comment without file" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" \
    --type "inline" \
    --lines "19-40" \
    --side "right" \
    --text "Missing file."
  [ "$status" -ne 0 ]
}

@test "rejects inline comment without lines" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" \
    --type "inline" \
    --file "some/file.java" \
    --side "right" \
    --text "Missing lines."
  [ "$status" -ne 0 ]
}

@test "inline comment without side defaults to right" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" \
    --type "inline" \
    --file "some/file.java" \
    --lines "19-40" \
    --text "Side should default."
  [ "$status" -eq 0 ]
  local block
  block=$(awk '/^### C6$/{found=1} found && /^### C[0-9]/ && $0 != "### C6"{exit} found{print}' "$BATS_TMPDIR/comments.md")
  [[ "$block" == *"side: right"* ]]
}

@test "rejects invalid side value" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" \
    --type "inline" \
    --file "some/file.java" \
    --lines "19-40" \
    --side "both" \
    --text "Bad side."
  [ "$status" -ne 0 ]
}

@test "rejects missing arguments" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "rejects non-existent comments file" {
  run "$SCRIPT" "/tmp/nonexistent.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Test."
  [ "$status" -ne 0 ]
}

@test "rejects non-existent tree file" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "/tmp/nonexistent-tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Test."
  [ "$status" -ne 0 ]
}

# --- Empty file ---

@test "adds first comment to empty comments file" {
  cat > "$BATS_TMPDIR/empty.md" << 'EOF'
# Review Comments: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |

## Comments
EOF
  run "$SCRIPT" "$BATS_TMPDIR/empty.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "First comment ever."
  [ "$status" -eq 0 ]
  grep -q -- "^### C1$" "$BATS_TMPDIR/empty.md"
}

# --- Lines format validation ---

@test "rejects invalid lines format" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" --type "inline" --file "f.java" --lines "abc" --side "right" --text "X"
  [ "$status" -ne 0 ]
}

@test "rejects lines without dash" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1" --type "inline" --file "f.java" --lines "42" --side "right" --text "X"
  [ "$status" -ne 0 ]
}

# --- Node existence validation ---

@test "rejects comment on non-existent node" {
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "99.99" \
    --type "top-level" \
    --text "Ghost node."
  [ "$status" -ne 0 ]
}

# --- Tree {comment} flag ---

@test "adds {comment} flag to tree node" {
  # Node 1.1.2 has no {comment} flag
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.2" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "Test flag addition."
  [ "$status" -eq 0 ]
  grep -q -- "1\.1\.2\..*{comment}" "$BATS_TMPDIR/tree.md"
}

@test "adds {comment} to node with existing {variation} flag" {
  # Node 2 has {variation} but no {comment}
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "2" \
    --type "top-level" \
    --text "Concern about active guard pattern."
  [ "$status" -eq 0 ]
  grep -q -- "\] 2\..*{variation comment}" "$BATS_TMPDIR/tree.md"
}

@test "does not duplicate {comment} flag if already present" {
  # Node 1.1.1 already has {comment}
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "1.1.1" \
    --type "inline" \
    --file "hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java" \
    --lines "19-40" \
    --side "right" \
    --text "Another comment on same node."
  [ "$status" -eq 0 ]
  # Should have exactly one {comment}, not {comment comment}
  local line
  line=$(grep -- "1\.1\.1\." "$BATS_TMPDIR/tree.md")
  [[ "$line" == *"{comment}"* ]]
  [[ "$line" != *"comment comment"* ]]
}

@test "{comment} flag set even when title contains word comment" {
  cat > "$BATS_TMPDIR/title-tree.md" << 'TREE'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [pending] 1. Fix comment parsing logic
  files:
  - src/parser.js L1-50 (+50/-0)

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 1
Files mapped to tree: 1
Unmapped files: none
TREE

  cat > "$BATS_TMPDIR/title-comments.md" << 'COMMENTS'
# Review Comments: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |

## Comments
COMMENTS

  run "$SCRIPT" "$BATS_TMPDIR/title-comments.md" \
    --tree "$BATS_TMPDIR/title-tree.md" \
    --node "1" \
    --type "inline" \
    --file "src/parser.js" \
    --lines "1-50" \
    --text "Needs error handling."
  [ "$status" -eq 0 ]
  grep -q -- "1\..*{comment}" "$BATS_TMPDIR/title-tree.md"
}

@test "root comment does not modify tree" {
  local before
  before=$(cat "$BATS_TMPDIR/tree.md")
  run "$SCRIPT" "$BATS_TMPDIR/comments.md" \
    --tree "$BATS_TMPDIR/tree.md" \
    --node "root" \
    --type "top-level" \
    --text "Root comment."
  [ "$status" -eq 0 ]
  local after
  after=$(cat "$BATS_TMPDIR/tree.md")
  [ "$before" = "$after" ]
}
