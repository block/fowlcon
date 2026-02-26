#!/usr/bin/env bats

# Tests for scripts/check-tree-quality.sh
# TDD: write tests first, then implement the script.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
SAMPLE="$REPO_ROOT/tests/formats/sample-tree-hawksbury.md"
SCRIPT="$REPO_ROOT/scripts/check-tree-quality.sh"

setup() {
  cp "$SAMPLE" "$BATS_TEST_TMPDIR/tree.md"
  # Generate the file list from the sample tree (all files referenced in it)
  grep -E '^\s+- .+ L[0-9]' "$SAMPLE" | sed -E 's/^[[:space:]]+-[[:space:]]//' | sed -E 's/ L[0-9]+.*//' | sort -u > "$BATS_TEST_TMPDIR/files.txt"
}

# --- Pass on valid tree ---

@test "passes on valid Hawksbury sample tree" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

# --- File coverage ---

@test "fails when diff file is not mapped to any node" {
  # Add an unmapped file to the file list
  echo "src/main/java/com/hawksbury/orphan/UnmappedHandler.java" >> "$BATS_TEST_TMPDIR/files.txt"
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"UnmappedHandler.java"* ]]
  [[ "$output" == *"unmapped"* ]]
}

@test "passes when all diff files are in tree" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -eq 0 ]
}

# --- Top-level node count ---

@test "passes with 5 top-level nodes (under 7 threshold)" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -eq 0 ]
}

@test "fails when top-level nodes exceed threshold" {
  local tmpfile="$BATS_TEST_TMPDIR/big-tree.md"
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

- [pending] 1. Concept one
- [pending] 2. Concept two
- [pending] 3. Concept three
- [pending] 4. Concept four
- [pending] 5. Concept five
- [pending] 6. Concept six
- [pending] 7. Concept seven
- [pending] 8. Concept eight

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  echo -n "" > "$BATS_TEST_TMPDIR/empty-files.txt"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/empty-files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"top-level"* ]]
  [[ "$output" == *"8"* ]]
}

@test "configurable threshold via --max-top-level" {
  local tmpfile="$BATS_TEST_TMPDIR/big-tree.md"
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

- [pending] 1. Concept one
- [pending] 2. Concept two
- [pending] 3. Concept three
- [pending] 4. Concept four
- [pending] 5. Concept five
- [pending] 6. Concept six
- [pending] 7. Concept seven
- [pending] 8. Concept eight

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  echo -n "" > "$BATS_TEST_TMPDIR/empty-files.txt"
  # Raise threshold to 10 -- should pass
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/empty-files.txt" --max-top-level 10
  [ "$status" -eq 0 ]
}

# --- HEAD SHA ---

@test "fails when HEAD SHA is missing" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  sed -E '/^\| HEAD/d' "$SAMPLE" > "$tmpfile"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"HEAD"* ]]
}

# --- Description Verification ---

@test "fails when Description Verification section is missing" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  sed '/^## Description Verification/,/^## Coverage/{ /^## Coverage/!d; }' "$SAMPLE" > "$tmpfile"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Description Verification"* ]]
}

# --- Variation structure ---

@test "warns when variation node has no repeat children" {
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

- [reviewed] 1. Guard mechanism {variation}
  - [reviewed] 1.1. Example handler
    files:
    - src/Handler.java L1-10 (+10/-0)
  - [reviewed] 1.2. Another handler
    files:
    - src/Other.java L1-10 (+10/-0)

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 2
Files mapped to tree: 2
Unmapped files: none
EOF
  cat > "$BATS_TEST_TMPDIR/var-files.txt" << 'FILELIST'
src/Handler.java
src/Other.java
FILELIST
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/var-files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}

# --- Revision field ---

@test "fails when Revision field is missing" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  sed -E '/^\| Revision/d' "$SAMPLE" > "$tmpfile"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Revision"* ]]
}

# --- Input validation ---

@test "rejects missing arguments" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "rejects non-existent tree file" {
  run "$SCRIPT" "/tmp/nonexistent.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -ne 0 ]
}

@test "rejects non-existent file list" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "/tmp/nonexistent.txt"
  [ "$status" -ne 0 ]
}

# --- Output format ---

@test "output lists all checks performed" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HEAD SHA"* ]]
  [[ "$output" == *"Revision"* ]]
  [[ "$output" == *"top-level"* ]]
  [[ "$output" == *"file coverage"* ]]
  [[ "$output" == *"Description Verification"* ]]
}

@test "no warnings on valid Hawksbury sample" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

# --- Regression tests ---

@test "variation check catches {variation comment} nodes" {
  local tmpfile="$BATS_TEST_TMPDIR/var-comment.md"
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

- [accepted] 1. Pattern group {variation comment}
  - [accepted] 1.1. Example
    files:
    - src/A.java L1-5 (+5/-0)
  - [accepted] 1.2. Not a repeat
    files:
    - src/B.java L1-5 (+5/-0)

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 2
Files mapped to tree: 2
Unmapped files: none
EOF
  cat > "$BATS_TEST_TMPDIR/vc-files.txt" << 'FILELIST'
src/A.java
src/B.java
FILELIST
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/vc-files.txt"
  [ "$status" -eq 0 ]
  # Should WARN about node 1 having no {repeat} children
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"variation node 1"* ]]
}

@test "file coverage requires exact path match" {
  local tmpfile="$BATS_TEST_TMPDIR/tree.md"
  # File list has short name, tree has full path -- should fail
  echo "Handler.java" > "$BATS_TEST_TMPDIR/short-files.txt"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/short-files.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Handler.java"* ]]
  [[ "$output" == *"unmapped"* ]]
}

@test "passes with exactly max-top-level nodes (boundary)" {
  local tmpfile="$BATS_TEST_TMPDIR/seven.md"
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

- [pending] 1. One
- [pending] 2. Two
- [pending] 3. Three
- [pending] 4. Four
- [pending] 5. Five
- [pending] 6. Six
- [pending] 7. Seven

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  echo -n "" > "$BATS_TEST_TMPDIR/empty-files.txt"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/empty-files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"top-level concepts: 7"* ]]
}

@test "passes with empty file list" {
  echo -n "" > "$BATS_TEST_TMPDIR/empty-files.txt"
  run "$SCRIPT" "$BATS_TEST_TMPDIR/tree.md" "$BATS_TEST_TMPDIR/empty-files.txt"
  [ "$status" -eq 0 ]
}

@test "reports all failures not just the first" {
  local tmpfile="$BATS_TEST_TMPDIR/broken.md"
  cat > "$tmpfile" << 'EOF'
# Review Tree: Test

| Field       | Value |
|-------------|-------|
| PR          | test/test#1 |
| Tree Built  | 2026-02-25T10:00:00Z |
| Updated     | 2026-02-25T10:00:00Z |

## Tree

- [pending] 1. Only concept

## Coverage

Total files in diff: 0
Files mapped to tree: 0
Unmapped files: none
EOF
  echo -n "" > "$BATS_TEST_TMPDIR/empty-files.txt"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/empty-files.txt"
  [ "$status" -ne 0 ]
  # Should report all three missing: HEAD, Revision, Description Verification
  [[ "$output" == *"HEAD SHA"* ]]
  [[ "$output" == *"Revision"* ]]
  [[ "$output" == *"Description Verification"* ]]
}

@test "variation warning does not cause exit failure" {
  local tmpfile="$BATS_TEST_TMPDIR/var-warn.md"
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

- [reviewed] 1. Guard mechanism {variation}
  - [reviewed] 1.1. Example handler
    files:
    - src/Handler.java L1-10 (+10/-0)

## Description Verification

| # | Claim | Status | Evidence |

## Coverage

Total files in diff: 1
Files mapped to tree: 1
Unmapped files: none
EOF
  echo "src/Handler.java" > "$BATS_TEST_TMPDIR/vw-files.txt"
  run "$SCRIPT" "$tmpfile" "$BATS_TEST_TMPDIR/vw-files.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}
