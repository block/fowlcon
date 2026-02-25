#!/usr/bin/env bats

# Tests for review-tree.md parsing patterns from the format spec.
# Mirrors the comment parsing tests -- ensures tree format is equally
# well-tested for downstream shell scripts (Tasks 3-6).

SAMPLE="tests/formats/sample-tree-hawksbury.md"

# --- Header structure ---

@test "file starts with review tree title" {
  run bash -c "head -1 '$SAMPLE'"
  [ "$status" -eq 0 ]
  [[ "$output" == "# Review Tree:"* ]]
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

@test "header contains Revision counter" {
  run grep '^| Revision' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
}

@test "## Tree section header exists" {
  run grep -c '^## Tree$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "## Description Verification section exists" {
  run grep -c '^## Description Verification$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "## Coverage section exists" {
  run grep -c '^## Coverage$' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# --- Node ID operations ---

@test "find all node IDs" {
  run grep -oE '\[(pending|reviewed|accepted)\] [0-9]+(\.[0-9]+)*\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -gt 0 ]
}

@test "count nodes by status" {
  local pending reviewed accepted
  pending=$(grep -c '\[pending\]' "$SAMPLE")
  reviewed=$(grep -c '\[reviewed\]' "$SAMPLE")
  accepted=$(grep -c '\[accepted\]' "$SAMPLE")
  [ "$pending" -ge 1 ]
  [ "$reviewed" -ge 1 ]
  [ "$accepted" -ge 1 ]
  # Total should match total node count
  local total
  total=$(grep -cE '^\s*- \[(pending|reviewed|accepted)\]' "$SAMPLE")
  [ "$((pending + reviewed + accepted))" -eq "$total" ]
}

@test "find specific node by ID (top-level)" {
  run grep -E '^\s*- \[(pending|reviewed|accepted)\] 2\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active guard"* ]]
}

@test "find specific node by ID (nested)" {
  run grep -E '^\s*- \[(pending|reviewed|accepted)\] 1\.1\.1\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Feature flag integration"* ]]
}

@test "find specific node by ID (deep: 2.1.10)" {
  run grep -E '^\s*- \[(pending|reviewed|accepted)\] 2\.1\.10\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GetNestingAssetsInternalApi"* ]]
}

@test "dot-separated ID regex does not false-match prefix (2.1.1 vs 2.1.10)" {
  # Regex for 2.1.1 should not match 2.1.10
  run bash -c "grep -cE '^\s*- \[.*\] 2\.1\.1\. ' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]  # Only 2.1.1, not 2.1.10
}

# --- Status update (sed patterns from spec) ---

@test "sed updates node status" {
  local tmpfile="$BATS_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  /usr/bin/sed -E 's/^([[:space:]]*- \[)(pending)(\] 5\.)/\1reviewed\3/' "$tmpfile" > "$tmpfile.tmp" && mv "$tmpfile.tmp" "$tmpfile"
  run grep '\] 5\.' "$tmpfile"
  [[ "$output" == *"[reviewed]"* ]]
  [[ "$output" == *"5. CLAUDE.md"* ]]
}

@test "sed does not affect other nodes when updating" {
  local tmpfile="$BATS_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  /usr/bin/sed -E 's/^([[:space:]]*- \[)(pending)(\] 5\.)/\1reviewed\3/' "$tmpfile" > "$tmpfile.tmp" && mv "$tmpfile.tmp" "$tmpfile"
  # Node 1 should still be reviewed, not changed
  run grep '\] 1\. Core' "$tmpfile"
  [[ "$output" == *"[reviewed]"* ]]
}

# --- Flag operations ---

@test "find all variation nodes" {
  run grep '{variation}' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
}

@test "find all repeat nodes" {
  run grep '{repeat' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
}

@test "count repeat nodes" {
  run bash -c "grep -c '{repeat' '$SAMPLE'"
  [ "$status" -eq 0 ]
  local count=$output
  # Should be more than the variation nodes (many repeats per variation)
  local variations
  variations=$(grep -c '{variation}' "$SAMPLE")
  [ "$count" -gt "$variations" ]
}

@test "find nodes with comment flag" {
  run grep 'comment}' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.1"* ]]
  [[ "$output" == *"2.1.3"* ]]
  [[ "$output" == *"2.1.5"* ]]
  [[ "$output" == *"] 3."* ]]
  # Exactly 4 nodes have comment flag
  run bash -c "grep -c 'comment}' '$SAMPLE'"
  [ "$output" = "4" ]
}

@test "add comment flag to node without flags (awk)" {
  local tmpfile="$BATS_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  awk '
/^[[:space:]]*- \[.*\] 1\.1\.2\./ && !/\{/ { $0 = $0 " {comment}" }
{ print }
' "$tmpfile" > "$tmpfile.tmp" && mv "$tmpfile.tmp" "$tmpfile"
  run grep '1\.1\.2\.' "$tmpfile"
  [[ "$output" == *"{comment}"* ]]
}

@test "add flag to node with existing flags (awk)" {
  local tmpfile="$BATS_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  # Node 2 has {variation} -- add comment flag to it
  awk '
/^- \[.*\] 2\. / && /\{/ { sub(/\}/, " comment}") }
{ print }
' "$tmpfile" > "$tmpfile.tmp" && mv "$tmpfile.tmp" "$tmpfile"
  run grep '^- \[.*\] 2\.' "$tmpfile"
  [[ "$output" == *"{variation comment}"* ]]
}

# --- File mapping extraction ---

@test "extract file entries from a leaf node" {
  run awk '
/^[[:space:]]*- \[.*\] 1\.1\.1\./ { found=1; next }
found && /^[[:space:]]*files:/ { in_files=1; next }
found && in_files && /^[[:space:]]*- [a-zA-Z]/ { print; next }
found && in_files && !/^[[:space:]]*- [a-zA-Z]/ { exit }
found && /^[[:space:]]*- \[/ { exit }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RoostGuard.java"* ]]
  [[ "$output" == *"L1-18"* ]]
  [[ "$output" == *"L19-40"* ]]
}

@test "leaf nodes have files, non-leaf nodes do not" {
  # Node 1 (non-leaf, has children) should not have files:
  run bash -c "awk '/^\- \[.*\] 1\. Core/{found=1} found && /^  files:/{print \"FAIL\"; exit 1} found && /^\- \[/{exit}' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"FAIL"* ]]
}

@test "count unique files in tree" {
  run bash -c "grep -E '^\s+- .+\.(java|md) L' '$SAMPLE' | /usr/bin/sed -E 's/ L[0-9]+.*//' | sort -u | wc -l | tr -d ' '"
  [ "$status" -eq 0 ]
  # Coverage section says 32 files
  local coverage_count
  coverage_count=$(grep 'Total files in diff:' "$SAMPLE" | grep -oE '[0-9]+')
  [ "$output" = "$coverage_count" ]
}

# --- Coverage section ---

@test "coverage counts are consistent" {
  local total mapped
  total=$(grep 'Total files in diff:' "$SAMPLE" | grep -oE '[0-9]+')
  mapped=$(grep 'Files mapped to tree:' "$SAMPLE" | grep -oE '[0-9]+')
  [ "$total" = "$mapped" ]
}

@test "no unmapped files" {
  run grep 'Unmapped files:' "$SAMPLE"
  [[ "$output" == *"none"* ]]
}

# --- Description Verification ---

@test "description verification table exists" {
  run grep -c '^| [0-9]' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "verification statuses are valid" {
  run bash -c "grep '^| [0-9]' '$SAMPLE' | grep -cvE 'verified|unverified|contradicted|undocumented'"
  # All rows should match one of the valid statuses (count of non-matching = 0)
  [ "$output" = "0" ]
}

# --- Context blocks ---

@test "context blocks exist on nodes" {
  run bash -c "grep -c '^\s*context:' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "context appears before files (ordering rule)" {
  # For node 1.1.1 which has both context and files:
  local context_line files_line
  context_line=$(grep -n 'Reads hawksbury-roost-mode flag' "$SAMPLE" | head -1 | cut -d: -f1)
  files_line=$(grep -n 'RoostGuard.java L1-18' "$SAMPLE" | head -1 | cut -d: -f1)
  [ "$context_line" -lt "$files_line" ]
}

@test "context appears before children (ordering rule)" {
  # For node 1 which has context and children:
  local context_line child_line
  context_line=$(grep -n 'New singleton guard that controls' "$SAMPLE" | head -1 | cut -d: -f1)
  child_line=$(grep -n '\] 1\.1\. RoostGuard' "$SAMPLE" | head -1 | cut -d: -f1)
  [ "$context_line" -lt "$child_line" ]
}

# --- Patterns for downstream scripts (Tasks 3-6) ---

@test "extract multi-line context block" {
  # Node 1.1 has a multi-line context: | block
  run awk '
/^[[:space:]]*- \[.*\] 1\.1\. RoostGuard/ { found=1; next }
found && /^[[:space:]]*context: \|/ { in_ctx=1; next }
found && in_ctx && /^[[:space:]]{6,}[^ ]/ { print; next }
found && in_ctx { exit }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"40-line singleton"* ]]
  [[ "$output" == *"catch block defaults to SILENT"* ]]
}

@test "extract single-line context" {
  # Node 4.1 has context: "Author states: ..."
  run awk '
/^[[:space:]]*- \[.*\] 4\.1\./ { found=1; next }
found && /^[[:space:]]*context:/ { print; exit }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tier-0 critical API"* ]]
}

@test "status update on nested node preserves flags" {
  local tmpfile="$BATS_TMPDIR/tree.md"
  cp "$SAMPLE" "$tmpfile"
  # Update node 2.1.5 (has {repeat comment}) from accepted to reviewed
  /usr/bin/sed -E 's/^([[:space:]]*- \[)(accepted)(\] 2\.1\.5\.)/\1reviewed\3/' "$tmpfile" > "$tmpfile.tmp" && mv "$tmpfile.tmp" "$tmpfile"
  run grep '2\.1\.5\.' "$tmpfile"
  [[ "$output" == *"[reviewed]"* ]]
  [[ "$output" == *"{repeat comment}"* ]]
}

@test "count top-level nodes" {
  run bash -c "grep -cE '^- \[(pending|reviewed|accepted)\]' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

@test "variation nodes have repeat children" {
  # For each {variation} node, verify at least one child has {repeat}
  # Node 2.1 is a variation -- children 2.1.2-2.1.10 are repeats
  run bash -c "awk '
/^[[:space:]]*- \[.*\] 2\.1\. .*\{variation\}/ { in_var=1; has_repeat=0; next }
in_var && /\{repeat/ { has_repeat=1 }
in_var && /^[[:space:]]*- \[.*\] 2\.2\./ { if (!has_repeat) exit 1; exit 0 }
in_var && /^- \[/ { if (!has_repeat) exit 1; exit 0 }
' '$SAMPLE'"
  [ "$status" -eq 0 ]
}

@test "multiple hunks per file" {
  # Node 1.1.1 has RoostGuard.java twice with different line ranges
  run bash -c "awk '
/^[[:space:]]*- \[.*\] 1\.1\.1\./ { found=1; next }
found && /^[[:space:]]*files:/ { in_files=1; next }
found && in_files && /RoostGuard\.java/ { count++ }
found && in_files && !/^[[:space:]]*-/ { exit }
found && /^[[:space:]]*- \[/ { exit }
END { print count }
' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "extract HEAD SHA programmatically" {
  run bash -c "grep '| HEAD' '$SAMPLE' | awk -F'|' '{print \$3}' | tr -d ' '"
  [ "$status" -eq 0 ]
  [ "$output" = "27748881a1cb5eb58ed39c3ed2095038cb0cc62a" ]
}

# --- Robustness ---

@test "context with parser-confusing text does not break node finding" {
  # Create a fixture where a context block contains text that looks like
  # a node line and a files: delimiter. The node-finding pattern must not
  # false-match inside context text.
  local tmpfile="$BATS_TMPDIR/confusing.md"
  cat > "$tmpfile" << 'FIXTURE'
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
    The node structure looks like this:
    - [pending] 1.1. This is NOT a real node
    files:
    - fake/path.java L1-10 (+10/-0)
    The above lines are just prose in the context block.
  - [pending] 1.1. Real child node
    files:
    - real/path.java L1-5 (+5/-0)

## Description Verification

| # | Claim | Status | Evidence |
|---|-------|--------|----------|

## Coverage

Total files in diff: 1
Files mapped to tree: 1
Unmapped files: none
FIXTURE

  # KNOWN LIMITATION: grep matches BOTH the fake node in context AND the
  # real node. The grep pattern has no way to know it's inside a context block.
  # This proves the vulnerability exists.
  run bash -c "grep -cE '^[[:space:]]*- \[(pending|reviewed|accepted)\] 1\.1\.' '$tmpfile'"
  [ "$output" = "2" ]  # BUG: should be 1, but grep sees the fake node too

  # The awk file-extraction pattern ALSO hits the fake files: block first,
  # extracting fake/path.java instead of real/path.java.
  run awk '
/^[[:space:]]*- \[(pending|reviewed|accepted)\] 1\.1\./ { found=1; next }
found && /^[[:space:]]*files:/ { in_files=1; next }
found && in_files && /^[[:space:]]*- [a-zA-Z]/ { print; next }
found && in_files && !/^[[:space:]]*- [a-zA-Z]/ { exit }
found && /^[[:space:]]*- \[/ { exit }
' "$tmpfile"
  [ "$status" -eq 0 ]
  # This extracts the FAKE path -- proving the parser is fooled by context content.
  # Scripts that need accurate results must skip context: blocks before matching.
  [[ "$output" == *"fake/path.java"* ]]
}

@test "repeat nodes have files but no subtree" {
  # Pick repeat node 2.1.2 (at 4-space indent) -- should have files:
  # but no child nodes at deeper indentation (6+ spaces)
  run awk '
/^    - \[.*\] 2\.1\.2\./ { found=1; indent=4; next }
found && /^[[:space:]]*files:/ { has_files=1; next }
found && /^      - \[/ { has_children=1 }
found && /^    - \[/ { exit }
found && /^  - \[/ { exit }
found && /^- \[/ { exit }
END { if (has_files && !has_children) print "PASS"; else print "FAIL" }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "$output" = "PASS" ]
}

@test "leaf detection by absence of child nodes" {
  # Node 1.2 (test infrastructure, at 2-space indent) is non-leaf
  # -- has children at 4-space indent (1.2.1, 1.2.2)
  run awk '
/^  - \[.*\] 1\.2\. / { found=1; next }
found && /^    - \[/ { print "has_children"; exit }
found && /^  - \[/ { print "no_children"; exit }
found && /^- \[/ { print "no_children"; exit }
' "$SAMPLE"
  [ "$output" = "has_children" ]

  # Node 5 (CLAUDE.md, top-level) is a leaf -- no children at 2+ spaces
  run awk '
/^- \[.*\] 5\. / { found=1; next }
found && /^  - \[/ { result="has_children"; exit }
found && /^##/ { result="no_children"; exit }
END { if (result) print result; else if (found) print "no_children" }
' "$SAMPLE"
  [ "$output" = "no_children" ]
}

# --- Edge cases ---

@test "IDs are sequential at top level" {
  run bash -c "grep -oE '^- \[(pending|reviewed|accepted)\] [0-9]+\.' '$SAMPLE' | grep -oE '[0-9]+\.' | /usr/bin/sed 's/\.//' | sort -n"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1" ]
  [ "${lines[1]}" = "2" ]
  [ "${lines[2]}" = "3" ]
  [ "${lines[3]}" = "4" ]
  [ "${lines[4]}" = "5" ]
}

@test "multi-digit node IDs parse correctly (2.1.10, 3.13)" {
  run grep '2\.1\.10\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GetNestingAssetsInternalApi"* ]]

  run grep '3\.13\.' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SetNestTagAppApi"* ]]
}

@test "no stale naming (pattern:N, franklin, squareup)" {
  run bash -c "grep -ciE 'pattern:[0-9]|franklin|squareup' '$SAMPLE'"
  [ "$output" = "0" ]
}
