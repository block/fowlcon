#!/usr/bin/env bats

# Tests for review-comments.md parsing patterns from the format spec.
# These are load-bearing patterns used by shell scripts -- cross-platform
# breakage (BSD vs GNU) must be caught here.

SAMPLE="tests/formats/sample-comments-hawksbury.md"

# --- Basic ID operations ---

@test "find all comment IDs" {
  run grep -oE '^### C[0-9]+' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "### C1" ]
  [ "${lines[1]}" = "### C2" ]
  [ "${lines[2]}" = "### C3" ]
  [ "${lines[3]}" = "### C4" ]
  [ "${lines[4]}" = "### C5" ]
  [ "${#lines[@]}" -eq 5 ]
}

@test "get highest comment ID" {
  run bash -c "grep -oE '^### C([0-9]+)' '$SAMPLE' | sort -t'C' -k2 -n | tail -1"
  [ "$status" -eq 0 ]
  [ "$output" = "### C5" ]
}

@test "count total comments" {
  run bash -c "grep -cE '^### C[0-9]+' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

# --- Extract specific comments ---

@test "extract first comment (C1)" {
  run awk '
/^### C1$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C1" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "### C1" ]]
  [[ "$output" == *"node: 1.1.1"* ]]
  [[ "$output" == *"type: inline"* ]]
  [[ "$output" == *"catch block defaults to SILENT"* ]]
  # Should not contain C2 content
  [[ "$output" != *"node: root"* ]]
}

@test "extract middle comment (C3)" {
  run awk '
/^### C3$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C3" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "### C3" ]]
  [[ "$output" == *"node: 2.1.5"* ]]
  [[ "$output" == *"plumage"* ]]
  # Should not contain C4 content
  [[ "$output" != *"node: 3"* ]]
}

@test "extract last comment (C5)" {
  run awk '
/^### C5$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C5" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "### C5" ]]
  [[ "$output" == *"status: deleted"* ]]
  [[ "$output" == *"import order is correct"* ]]
}

@test "extract non-existent comment returns empty" {
  run awk '
/^### C99$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C99" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- Filter by node ---

@test "find all comments for node 1.1.1" {
  run grep -A1 '^node: 1.1.1$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"node: 1.1.1"* ]]
  [[ "$output" == *"type: inline"* ]]
}

@test "find comments for node with no comments returns empty" {
  run grep '^node: 9.9.9$' "$SAMPLE"
  [ "$status" -eq 1 ]
}

# --- Filter by status ---

@test "find all active comments excludes deleted" {
  run bash -c "diff <(grep -oE '^### C[0-9]+' '$SAMPLE') <(grep -B5 '^status: deleted' '$SAMPLE' | grep -oE '^### C[0-9]+') | grep '^< ' | sed 's/^< //'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"### C1"* ]]
  [[ "$output" == *"### C2"* ]]
  [[ "$output" == *"### C3"* ]]
  [[ "$output" == *"### C4"* ]]
  # C5 is deleted, should not appear
  [[ "$output" != *"### C5"* ]]
}

# --- Filter by type ---

@test "find all inline comments" {
  run grep -B1 '^type: inline$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"node: 1.1.1"* ]]
  [[ "$output" == *"node: 2.1.5"* ]]
  [[ "$output" == *"node: 2.1.3"* ]]
  # Top-level nodes should not appear
  [[ "$output" != *"node: root"* ]]
  [[ "$output" != *"node: 3"* ]]
}

@test "find all top-level comments" {
  run grep -B1 '^type: top-level$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"node: root"* ]]
  [[ "$output" == *"node: 3"* ]]
  # Inline nodes should not appear
  [[ "$output" != *"node: 1.1.1"* ]]
  [[ "$output" != *"node: 2.1.5"* ]]
}

# --- Filter by file ---

@test "find all comments for a specific file" {
  run grep -B6 'RoostGuard.java' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"### C1"* ]]
  # Only C1 references RoostGuard.java
  [[ "$output" != *"### C3"* ]]
}

@test "find comments across files in a package" {
  run grep '^file:.*hawksbury/sanctuary/v2/' "$SAMPLE"
  [ "$status" -eq 0 ]
  # C5 (SetPlumagePhotoAppApi) is in sanctuary/v2
  [[ "$output" == *"SetPlumagePhotoAppApi"* ]]
}

# --- Header structure ---

@test "file starts with review comments title" {
  run bash -c "head -1 '$SAMPLE'"
  [ "$status" -eq 0 ]
  [[ "$output" == "# Review Comments:"* ]]
}

@test "header contains PR field" {
  run grep '^| PR' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hawksbury/hawksbury#34429"* ]]
}

@test "header contains HEAD SHA" {
  run grep '^| HEAD' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"27748881a1cb5eb58ed39c3ed2095038cb0cc62a"* ]]
}

@test "## Comments section header exists" {
  run grep -c '^## Comments$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# --- Active-comments edge cases ---

@test "active filter works when no comments are deleted" {
  local tmpfile="$BATS_TMPDIR/all-active.md"
  cat > "$tmpfile" << 'EOF'
# Review Comments: Test

| Field | Value |
|-------|-------|
| PR    | test/test#1 |
| HEAD  | abc123 |

## Comments

### C1
node: 1.1
type: top-level
status: active
source: reviewer
tree_rev: 1
created: 2026-02-25T10:00:00Z

First comment.

### C2
node: 2.1
type: top-level
status: active
source: reviewer
tree_rev: 1
created: 2026-02-25T10:05:00Z

Second comment.
EOF
  run bash -c "diff <(grep -oE '^### C[0-9]+' '$tmpfile') <(grep -B5 '^status: deleted' '$tmpfile' | grep -oE '^### C[0-9]+') 2>/dev/null | grep '^< ' | sed 's/^< //'"
  # When no deleted comments, diff's right side is empty, all IDs appear
  [[ "$output" == *"### C1"* ]]
  [[ "$output" == *"### C2"* ]]
}

@test "active filter returns empty when all comments are deleted" {
  local tmpfile="$BATS_TMPDIR/all-deleted.md"
  cat > "$tmpfile" << 'EOF'
# Review Comments: Test

| Field | Value |
|-------|-------|
| PR    | test/test#1 |
| HEAD  | abc123 |

## Comments

### C1
node: 1.1
type: top-level
status: deleted
source: reviewer
tree_rev: 1
created: 2026-02-25T10:00:00Z

Deleted.

### C2
node: 2.1
type: top-level
status: deleted
source: reviewer
tree_rev: 1
created: 2026-02-25T10:05:00Z

Also deleted.
EOF
  run bash -c "diff <(grep -oE '^### C[0-9]+' '$tmpfile') <(grep -B5 '^status: deleted' '$tmpfile' | grep -oE '^### C[0-9]+') 2>/dev/null | grep '^< ' | sed 's/^< //'"
  [ -z "$output" ]
}

# --- Structural validation ---

@test "inline comments all have file, lines, and side" {
  # For each inline comment, extract its block and check required fields
  local ids
  ids=$(grep -B1 '^type: inline$' "$SAMPLE" | grep -oE '^node: .+' | sed 's/node: //')
  for node_id in $ids; do
    run awk -v nid="$node_id" '
/^node: / && $2 == nid { found=1; has_file=0; has_lines=0; has_side=0 }
found && /^file:/ { has_file=1 }
found && /^lines:/ { has_lines=1 }
found && /^side:/ { has_side=1 }
found && /^$/ { if (!has_file || !has_lines || !has_side) exit 1; found=0 }
' "$SAMPLE"
    [ "$status" -eq 0 ]
  done
}

@test "top-level comments have no file, lines, or side" {
  # Extract each top-level comment block and verify absence of inline-only fields
  run bash -c "
    awk '
    /^type: top-level/ { in_toplevel=1 }
    in_toplevel && /^file:/ { print \"FAIL: top-level has file\"; exit 1 }
    in_toplevel && /^lines:/ { print \"FAIL: top-level has lines\"; exit 1 }
    in_toplevel && /^side:/ { print \"FAIL: top-level has side\"; exit 1 }
    in_toplevel && /^$/ { in_toplevel=0 }
    ' '$SAMPLE'
  "
  [ "$status" -eq 0 ]
}

@test "all comments have tree_rev" {
  local total
  total=$(grep -cE '^### C[0-9]+' "$SAMPLE")
  local with_rev
  with_rev=$(grep -c '^tree_rev:' "$SAMPLE")
  [ "$total" -eq "$with_rev" ]
}

@test "timestamps are in sequential order" {
  run bash -c "grep '^created:' '$SAMPLE' | sed 's/created: //' | sort -c 2>&1"
  [ "$status" -eq 0 ]
}

# --- Body parsing ---

@test "comment body with markdown backticks is not mistaken for metadata" {
  # C1 contains backtick-formatted code in its body
  run awk '
/^### C1$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C1" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  # The backtick content should be in the output, not parsed as a field
  [[ "$output" == *'logger.warn'* ]]
}
