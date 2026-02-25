#!/usr/bin/env bats

# Tests for scripts/update-node-status.sh
# TDD: write tests first, then implement the script.

SAMPLE="tests/formats/sample-tree-hawksbury.md"
SCRIPT="scripts/update-node-status.sh"

setup() {
  cp "$SAMPLE" "$BATS_TMPDIR/tree.md"
}

# --- Basic status updates ---

@test "updates a pending node to reviewed" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*5\. CLAUDE.md" "$BATS_TMPDIR/tree.md"
}

@test "updates a pending node to accepted" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "accepted"
  [ "$status" -eq 0 ]
  grep -q -- "\[accepted\].*5\. CLAUDE.md" "$BATS_TMPDIR/tree.md"
}

@test "updates a reviewed node to accepted" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1.1.1" "accepted"
  [ "$status" -eq 0 ]
  grep -q -- "\[accepted\].*1\.1\.1\. Feature flag" "$BATS_TMPDIR/tree.md"
}

@test "updates an accepted node to reviewed" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "2" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*2\. Active guard" "$BATS_TMPDIR/tree.md"
}

@test "updates any status to pending (reset)" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1.1.1" "pending"
  [ "$status" -eq 0 ]
  grep -q -- "\[pending\].*1\.1\.1\. Feature flag" "$BATS_TMPDIR/tree.md"
}

# --- Nested nodes and flags ---

@test "updates nested node with flags (flags survive)" {
  # Node 2.1.5 has {repeat comment} -- flags must not be clobbered
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "2.1.5" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*2\.1\.5\..*{repeat comment}" "$BATS_TMPDIR/tree.md"
}

@test "updates variation node (flag survives)" {
  # Node 3 has {variation comment}
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "3" "pending"
  [ "$status" -eq 0 ]
  grep -q -- "\[pending\].*3\..*{variation comment}" "$BATS_TMPDIR/tree.md"
}

@test "updates multi-digit node ID (2.1.10)" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "2.1.10" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*2\.1\.10\. GetNestingAssetsInternalApi" "$BATS_TMPDIR/tree.md"
}

# --- Isolation ---

@test "does not affect other nodes" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "reviewed"
  [ "$status" -eq 0 ]
  # Node 1 should still be reviewed (unchanged)
  grep -q -- "\[reviewed\].*1\. Core" "$BATS_TMPDIR/tree.md"
  # Node 2 should still be accepted (unchanged)
  grep -q -- "\[accepted\].*2\. Active guard" "$BATS_TMPDIR/tree.md"
}

@test "does not match prefix IDs (2.1 vs 2.1.1)" {
  # Update 2.1 but NOT 2.1.1, 2.1.2, etc.
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "2.1" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*2\.1\. Standard pattern" "$BATS_TMPDIR/tree.md"
  # 2.1.1 should still be accepted
  grep -q -- "\[accepted\].*2\.1\.1\. Example" "$BATS_TMPDIR/tree.md"
}

# --- Updates timestamp ---

@test "updates the Updated timestamp in header" {
  # Replace the timestamp with a known old value so we can detect the change
  # without sleeping
  sed -E 's/^(\| Updated[[:space:]]*\|[[:space:]]*).*/\12000-01-01T00:00:00Z |/' \
    "$BATS_TMPDIR/tree.md" > "$BATS_TMPDIR/tree.md.tmp" && mv "$BATS_TMPDIR/tree.md.tmp" "$BATS_TMPDIR/tree.md"
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "reviewed"
  [ "$status" -eq 0 ]
  local after
  after=$(grep -- '| Updated' "$BATS_TMPDIR/tree.md" | awk -F'|' '{print $3}' | tr -d ' ')
  [[ "$after" != "2000-01-01T00:00:00Z" ]]
  # Verify ISO 8601 format
  [[ "$after" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# --- Atomic writes ---

@test "writes atomically via temp file" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "reviewed"
  [ "$status" -eq 0 ]
  # No temp file should linger
  [ ! -f "$BATS_TMPDIR/tree.md.tmp" ]
}

# --- Input validation ---

@test "rejects invalid status" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1.1" "approved"
  [ "$status" -ne 0 ]
}

@test "rejects empty status" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1.1" ""
  [ "$status" -ne 0 ]
}

@test "rejects non-existent node ID" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "99.99" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects missing file argument" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "rejects non-existent file" {
  run "$SCRIPT" "/tmp/nonexistent-tree.md" "1.1" "reviewed"
  [ "$status" -ne 0 ]
}

@test "updating to same status is a no-op (succeeds)" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1.1.1" "reviewed"
  [ "$status" -eq 0 ]
  grep -q -- "\[reviewed\].*1\.1\.1\. Feature flag" "$BATS_TMPDIR/tree.md"
}

# --- Regex injection prevention ---

@test "rejects node ID with regex special characters" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1+" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with parentheses" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1(.)2" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with non-digit characters" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "abc" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with trailing dot" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1." "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with leading dot" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" ".1" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with double dots" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1..2" "reviewed"
  [ "$status" -ne 0 ]
}

@test "rejects node ID with spaces" {
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "1 .2" "reviewed"
  [ "$status" -ne 0 ]
}

# --- File integrity ---

@test "file line count unchanged after update" {
  local before after
  before=$(wc -l < "$BATS_TMPDIR/tree.md")
  run "$SCRIPT" "$BATS_TMPDIR/tree.md" "5" "reviewed"
  [ "$status" -eq 0 ]
  after=$(wc -l < "$BATS_TMPDIR/tree.md")
  [ "$before" -eq "$after" ]
}
