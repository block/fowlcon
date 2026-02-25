#!/usr/bin/env bats

# Edge case tests for review-comments.md parsing.
# Verifies that emojis, code blocks, non-ASCII text, markdown formatting,
# and metadata-like body content don't break parsing patterns.

SAMPLE="tests/formats/sample-comments-edge-cases.md"

# --- Emojis ---

@test "emoji comment extracts correctly" {
  run awk '
/^### C1$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C1" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"👍"* ]]
  [[ "$output" == *"🔥"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"❌"* ]]
  [[ "$output" == *"→"* ]]
}

@test "emoji comment ID parsing unaffected" {
  run grep -oE '^### C[0-9]+' "$SAMPLE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
}

# --- Code blocks ---

@test "code block in body does not break extraction" {
  run awk '
/^### C2$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C2" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RoostMode.BLOCK"* ]]
  [[ "$output" == *"RoostMode.CHIRP"* ]]
  # Should not leak into C3
  [[ "$output" != *"Markdown formatting test"* ]]
}

# --- Markdown formatting ---

@test "markdown headers in body do not create false comment delimiters" {
  # C3 body contains #### heading -- should not break ID counting
  run bash -c "grep -cE '^### C[0-9]+' '$SAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

@test "markdown table in body does not break extraction" {
  run awk '
/^### C3$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C3" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Column A"* ]]
  [[ "$output" == *"value 1"* ]]
  [[ "$output" == *"Blockquote"* ]]
}

@test "URL with special chars preserved in body" {
  run awk '
/^### C3$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C3" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"query=value&other=123#fragment"* ]]
}

# --- Metadata-like body content ---

@test "metadata-like lines in body do not produce false node matches" {
  # C4 body contains "node: 9.9.9" -- grep for node should only find
  # actual metadata, not body content.
  # The safe approach: extract the comment first, then grep metadata
  # from the header section (before the first blank line).
  run bash -c "
    awk '
    /^### C4\$/ { found=1; in_header=1 }
    found && /^### C[0-9]/ && \$0 != \"### C4\" { exit }
    found && in_header && /^\$/ { in_header=0 }
    found && in_header && /^node:/ { print }
    ' '$SAMPLE'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "node: 2.1" ]
}

@test "body with fake file: line does not affect file search" {
  # Count how many actual inline comments reference /etc/passwd
  # (should be 0 -- the /etc/passwd is in C4's body, not metadata)
  run bash -c "
    count=0
    for id in \$(grep -oE '^### C[0-9]+' '$SAMPLE' | sed 's/### //'); do
      node_file=\$(awk -v cid=\"\$id\" '
      /^### / && \$0 == \"### \" cid { found=1; in_header=1 }
      found && in_header && /^\$/ { in_header=0 }
      found && in_header && /^file:/ { print \$2 }
      found && /^### C[0-9]/ && \$0 != \"### \" cid { exit }
      ' '$SAMPLE')
      if [[ \"\$node_file\" == *\"/etc/passwd\"* ]]; then
        count=\$((count + 1))
      fi
    done
    echo \$count
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

# --- Non-ASCII text ---

@test "non-ASCII text preserved in extraction" {
  run awk '
/^### C5$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C5" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"café"* ]]
  [[ "$output" == *"über"* ]]
  [[ "$output" == *"这是一个测试"* ]]
  [[ "$output" == *"テスト"* ]]
  [[ "$output" == *"مرحبا"* ]]
}

@test "empty lines in body preserved" {
  run awk '
/^### C5$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C5" { exit }
found { print }
' "$SAMPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Like this one above"* ]]
}

# --- Delimiter safety ---

@test "h3 heading in body that does not start with C<digit> is safe" {
  # C3 contains #### (h4), which is fine. Verify ### followed by
  # non-C-digit text would also be safe.
  # The delimiter pattern is ^### C[0-9] -- "### Changes" would not match.
  run bash -c "echo '### Changes needed' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 1 ]  # Should not match
}

@test "### C followed by non-digit is safe" {
  run bash -c "echo '### Comparison of approaches' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 1 ]  # "### Co..." does not match "### C[0-9]"
}

@test "### C followed by digit IS the delimiter" {
  run bash -c "echo '### C3' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# --- Validation (add-comment.sh must enforce) ---

@test "reject body containing delimiter pattern" {
  # Simulates what add-comment.sh should check before writing
  body='Here is how to reference comment:
### C1
Like that.'
  run bash -c "echo '$body' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  # The script should REJECT this body -- the test proves detection works
}

@test "backtick-wrapped delimiter is safe" {
  # Inline code wrapping avoids the delimiter
  body='Reference comment \`### C1\` in prose.'
  run bash -c "echo '$body' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 1 ]  # Does not match -- safe
}

@test "delimiter inside fenced code block still matches (known limitation)" {
  # This is the documented limitation: the parser does NOT track fence state.
  # A ### C<digit> at line start inside a code block WILL be seen as a delimiter.
  # add-comment.sh must reject this even inside code fences.
  body='```
### C99
```'
  run bash -c "echo '$body' | grep -cE '^### C[0-9]'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  # This WILL match -- confirming the body must be rejected
}

@test "null bytes detected in body" {
  # Simulates validation: body with null byte should be detectable
  # Use tr to check for null bytes (portable across BSD/GNU)
  run bash -c "printf 'hello\x00world' | tr -d '\0' | wc -c | tr -d ' '"
  [ "$status" -eq 0 ]
  # Original is 11 chars (hello\0world), without null is 10
  [ "$output" = "10" ]
}
