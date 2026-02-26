#!/usr/bin/env bats

# Tests for scripts/coverage-report.sh
# TDD: write tests first, then implement the script.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
SAMPLE="$REPO_ROOT/tests/formats/sample-tree-hawksbury.md"
SCRIPT="$REPO_ROOT/scripts/coverage-report.sh"

# --- Status counts ---

@test "reports count of pending nodes" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 1"* ]]
}

@test "reports count of reviewed nodes" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reviewed: 14"* ]]
}

@test "reports count of accepted nodes" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"accepted: 28"* ]]
}

@test "reports total node count" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total: 43"* ]]
}

# --- Progress ---

@test "reports progress percentage" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  # 42 decided out of 43 = 97%
  [[ "$output" == *"decided: 42/43 (97%)"* ]]
}

# --- Comment counts ---

@test "reports count of nodes with comments" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"with comments: 4"* ]]
}

# --- Pending nodes list ---

@test "lists pending nodes" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5. CLAUDE.md"* ]]
}

@test "no pending nodes listed when all reviewed or accepted" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  "$REPO_ROOT/scripts/update-node-status.sh" "$tmpfile" "5" "reviewed"
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 0"* ]]
  [[ "$output" != *"Pending nodes:"* ]]
}

# --- Confidence summary ---

@test "reports confidence summary" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"examined in detail: 14"* ]]
  [[ "$output" == *"pattern-trusted: 28"* ]]
}

# --- Top-level summary ---

@test "reports top-level concept count" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"top-level concepts: 5"* ]]
}

# --- File coverage ---

@test "reports file coverage from tree" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"files in diff: 32"* ]]
  [[ "$output" == *"files mapped: 32"* ]]
  [[ "$output" == *"unmapped: none"* ]]
}

@test "output has Files section header" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Files"* ]]
}

# --- Output structure ---

@test "output has section headers" {
  run "$SCRIPT" "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Status"* ]]
  [[ "$output" == *"## Pending"* ]]
}

# --- Input validation ---

@test "rejects missing file argument" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "rejects non-existent file" {
  run "$SCRIPT" "/tmp/nonexistent-tree.md"
  [ "$status" -ne 0 ]
}

# --- Context inflation protection ---

@test "context block with status-like text does not inflate counts" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [reviewed] 1. Guard mechanism
  context: |
    Status markers in other systems:
    - [pending] means waiting for review
    - [accepted] means done

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 0"* ]]
  [[ "$output" == *"reviewed: 1"* ]]
  [[ "$output" == *"accepted: 0"* ]]
  [[ "$output" == *"total: 1"* ]]
}

# --- Edge cases ---

@test "handles tree with all nodes pending" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [pending] 1. First concept
- [pending] 2. Second concept

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 2"* ]]
  [[ "$output" == *"reviewed: 0"* ]]
  [[ "$output" == *"accepted: 0"* ]]
  [[ "$output" == *"decided: 0/2 (0%)"* ]]
}

@test "handles tree with all nodes reviewed" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [reviewed] 1. First concept
- [reviewed] 2. Second concept

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 0"* ]]
  [[ "$output" == *"reviewed: 2"* ]]
  [[ "$output" == *"decided: 2/2 (100%)"* ]]
  [[ "$output" != *"Pending nodes:"* ]]
}

@test "empty tree with no nodes reports zeros" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total: 0"* ]]
  [[ "$output" == *"decided: 0/0 (0%)"* ]]
}

@test "tree without Coverage section omits Files section" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [reviewed] 1. Only concept

## Description Verification

| # | Claim | Status | Evidence |
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reviewed: 1"* ]]
  [[ "$output" != *"## Files"* ]]
}

@test "reports unmapped files when present" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [reviewed] 1. Only concept

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 3
Files mapped to tree: 1
Unmapped files: src/util.java, src/config.yaml
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"files in diff: 3"* ]]
  [[ "$output" == *"files mapped: 1"* ]]
  [[ "$output" == *"unmapped: src/util.java, src/config.yaml"* ]]
}

@test "deeply nested pending node listed correctly" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| HEAD        | abc123 |
| Revision    | 1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [reviewed] 1. Top level
  - [reviewed] 1.1. Second level
    - [reviewed] 1.1.1. Third level
      - [pending] 1.1.1.1. Deep pending node

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  run "$SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending: 1"* ]]
  [[ "$output" == *"1.1.1.1. Deep pending node"* ]]
}
