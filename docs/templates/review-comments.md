# Review Comments Format Specification

This document defines the `review-comments.md` format -- the comment store for a
Fowlcon review session. In V1.0, this is the local record of reviewer feedback.
In V1.1, it becomes the draft review document for posting to GitHub.

## Header

Every review comments file starts with a metadata header:

```
# Review Comments: <PR title>

| Field       | Value |
|-------------|-------|
| PR          | <owner/repo#number> |
| HEAD        | <full commit SHA at time of analysis> |
```

The HEAD SHA matches the review tree's HEAD. When posting comments (V1.1), this
SHA is used for the GitHub API's `commit_id` parameter.

## Comments

Each comment is a block starting with `### C<N>` where N is a sequential integer.
Comments are append-only during a session -- new comments get the next available ID.
Deletions are soft: the comment stays in the file with `status: deleted` but is
excluded from posting and summaries.

### Comment Block Format

```
### C<N>
node: <dot-separated node ID or "root">
type: <inline or top-level>
status: <active or deleted>
source: <reviewer or bot name>
file: <path relative to repo root>
lines: L<start>-<end>
side: <right or left>
start_side: <right or left>
tree_rev: <integer>
created: <ISO 8601 timestamp>
updated: <ISO 8601 timestamp>

<free-text comment body>
```

### GitHub API Provenance

Several fields in this format are adopted directly from the GitHub Pull Request
Review API to avoid a translation layer at posting time:

- **`side: right/left`** -- GitHub's diff side concept. `right` = new file
  version (additions/changes), `left` = old file version (deletions).
- **`type: inline/top-level`** -- maps to GitHub's two comment types. `inline`
  = review comment (attached to code via the review comments API). `top-level`
  = review body text (not attached to specific code).
- **`lines: L<start>-<end>`** -- maps to GitHub's `start_line`/`line`
  parameters. These are actual file line numbers, NOT the deprecated `position`
  parameter (which was an offset from the `@@` hunk header).

Fields appear in the order shown. When optional fields are omitted, remaining
fields maintain their relative order. Parsing patterns depend on this ordering.

All field values are lowercase. The GitHub API expects uppercase for some values
(`RIGHT`/`LEFT` for side) -- the posting script must handle the transformation.

### Field Definitions

- **node**: The tree node this comment is attached to. Any valid node ID from
  the review tree (e.g., `1.1.2`, `3.5`, `2.1.1`). Use `root` for comments
  about the PR as a whole (not tied to any tree node). Comments on `{repeat}`
  nodes and non-leaf concept nodes are valid.

- **type**: One of:
  - `inline` -- attached to specific code. Must have `file`, `lines`, and
    `side` fields. Maps to a GitHub inline review comment in V1.1.
  - `top-level` -- about a concept or the PR generally. No `file`, `lines`,
    or `side` fields. Maps to the review body text in V1.1.

- **status**: One of:
  - `active` -- this comment will be included in summaries and V1.1 posting.
    Default; can be omitted (absence means active).
  - `deleted` -- soft-deleted by the reviewer. Stays in the file for audit
    trail but excluded from summaries and posting.

- **source**: Where this comment originated. One of:
  - `reviewer` -- the customer typed it during the walkthrough (default; can
    be omitted, absence means reviewer)
  - A bot or tool name (e.g., `graphite-agent`, `coderabbit`) -- imported from
    an existing PR comment. The orchestrator may import bot comments to surface
    them during the walkthrough. Imported comments have their body prefixed
    with the source name.

- **file**: (inline only) File path relative to repo root. Must match a path
  in the review tree's file entries. This is the stable anchor -- if the tree
  is restructured and node IDs change, the file+lines still identify the code.

- **lines**: (inline only) Line range in the format `L<start>-<end>`, matching
  the review tree's file entry format. For single-line comments, start and end
  are the same (e.g., `L42-42`). For the GitHub API (V1.1), start maps to
  `start_line` and end maps to `line`.

- **side**: (inline only) Which side of the diff the comment is anchored to.
  Part of the GitHub API's stable reference tuple (`commit_sha + path + line +
  side`). One of:
  - `right` -- commenting on new/changed code (the common case)
  - `left` -- commenting on deleted code ("why was this removed?")
  For multi-line comments that span both sides of the diff, add `start_side:`
  as an additional field.

- **tree_rev**: The tree's Revision counter at the time this comment was
  created. If a comment's `tree_rev` doesn't match the current tree Revision,
  the comment's `node` reference may be stale (the tree was restructured after
  the comment was made). The orchestrator must remap node references when
  restructuring the tree; this field detects when remapping was missed.

- **created**: ISO 8601 timestamp when the comment was captured. Used for
  ordering in the posted review.

- **updated**: (optional) ISO 8601 timestamp of the last modification. Absent
  means unmodified since creation. Set when:
  - Node reference remapped due to tree restructuring
  - Status changed (e.g., active → deleted)
  - Comment body edited (future)

### Comment Body

The free-text body follows the metadata fields, separated by a blank line.
The body continues until the next `### C<N>` heading or end of file.

The body can contain: markdown formatting, emojis, code blocks (fenced or
indented), URLs, non-ASCII text (CJK, Arabic, accented characters), empty
lines, and metadata-like text (e.g., `node: 1.1` in prose).

### Content Restrictions

**Hard restriction (enforced by `add-comment.sh`, causes corruption if violated):**

- The body MUST NOT contain `### C` followed by a digit (`0-9`) at the start
  of a line. This is the comment delimiter pattern (`^### C[0-9]`). If present,
  it splits the comment into two, corrupting both. This applies even inside
  fenced code blocks -- the parser does not track markdown fence state.
  - `add-comment.sh` must reject body text that matches `^### C[0-9]`
  - If the reviewer needs to reference a comment ID in prose, use inline code:
    `` `### C1` `` (backtick-wrapped) or rephrase as "comment C1"

**Soft restriction (causes incorrect grep results, not corruption):**

- Simple `grep`-based patterns (e.g., `grep '^node:'`) will match metadata-like
  text in the body as well as actual metadata. For accurate metadata extraction,
  use the awk extraction pattern (which respects the blank-line separator between
  header and body) rather than raw grep across the whole file.

**Validated by `add-comment.sh` (Task 4):**

- Body text must not contain null bytes
- Body text must not contain the delimiter pattern `^### C[0-9]`
- Metadata field values must be single-line (no embedded newlines)

### Examples

Inline comment on a leaf node:

```
### C1
node: 1.1.1
type: inline
source: reviewer
file: hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java
lines: L19-40
side: right
tree_rev: 1
created: 2026-02-24T11:00:00Z

The catch block defaults to SILENT on any exception, including unexpected ones.
If the LaunchDarkly client throws a network error or a deserialization bug, this
swallows it silently. Consider logging the exception even in SILENT mode.
```

Top-level comment (source omitted -- defaults to reviewer):

```
### C2
node: root
type: top-level
tree_rev: 1
created: 2026-02-24T11:15:00Z

Overall the guard pattern is clean. The three-mode approach gives good
operational flexibility. Main concern is the silent exception swallowing
noted in C1.
```

Comment on a `{repeat}` node:

```
### C3
node: 2.1.5
type: inline
source: reviewer
file: service/src/main/java/com/hawksbury/plumage/ChargeNestInternalApi.java
lines: L25-29
side: right
tree_rev: 1
created: 2026-02-24T11:20:00Z

This handler already has a @Deprecated annotation. Should the guard call
come before or after the deprecation check? Currently it's before, which
means the guard runs even for calls that would be rejected by the
deprecation logic anyway.
```

Comment on a non-leaf concept node (no specific code):

```
### C4
node: 3
type: top-level
tree_rev: 1
created: 2026-02-24T11:30:00Z

The commented-out guard approach makes me uneasy. 196 files with dead code
that will need a follow-up PR to activate. Is there a timeline for the
follow-up? If not, this is tech debt that will age poorly.
```

Deleted comment (soft-deleted by reviewer):

```
### C5
node: 2.1.3
type: inline
status: deleted
file: service/src/main/java/com/hawksbury/sanctuary/v2/SetPlumagePhotoAppApi.java
lines: L15-15
side: right
tree_rev: 1
created: 2026-02-24T11:25:00Z

(Reviewer retracted this comment after realizing the import order is correct.)
```

## V1.1 Posting Compatibility

Posting requires `gh` (GitHub CLI) as a runtime dependency. Both REST (`gh api`)
and GraphQL (`gh api graphql`) go through the same `gh` binary -- no separate
tooling needed. The orchestrator detects `gh` availability at startup via
existing precondition checks.

### Recommended: GraphQL API

GraphQL is the recommended posting API for V1.1:
- **Incremental**: add comments one at a time to a pending review (REST
  requires all-at-once via the submit endpoint)
- **Error isolation**: one bad comment placement doesn't fail the whole review
- **File-level comments**: supports `subject_type: "file"` for comments about
  a file without a specific line (useful for top-level comments that reference
  a specific file)
- **Pending reviews**: invisible until submitted, no notification spam

Workflow: create pending review → add comments incrementally → submit review.
All via `gh api graphql`.

REST (`gh api`) is the fallback if GraphQL is unavailable or for simpler
integrations.

### Comment Mapping

**Inline comments** map to the GitHub API as:
- `commit_id` → HEAD SHA from the file header
- `path` → `file` field
- `line` → end of `lines` range (the `<end>` in `L<start>-<end>`)
- `start_line` → start of `lines` range (omit if same as `line`)
- `side` → `side` field, uppercased (`right` → `RIGHT`, `left` → `LEFT`)
- `start_side` → `start_side` field, uppercased (if present)
- `body` → comment body text

Only comments with `status: active` (or no status field) are posted. Comments
with `status: deleted` are excluded.

**Top-level comments** are concatenated into the review body text, ordered by
`created` timestamp. Each top-level comment includes its node reference for
context (e.g., "**Re: node 3 (Commented-out guard):** ...").

### Graceful Degradation

If an inline comment cannot be placed (line not in diff, file renamed, SHA
mismatch), fall back to a top-level comment with a prefix indicating the
intended location:

```
(intended for path/to/file.java:42) Original comment text here...
```

The review still gets posted -- just with reduced precision for problematic
comments. The posting script should report which comments degraded so the
reviewer can decide whether to repost after fixing.

### Posting Notes

- Inline comments are posted in creation order. GitHub renders them in diff
  order regardless of posting order, so the posting sequence is cosmetic.
- The posting script can optionally sort by node ID (tree traversal order)
  for a more logical posting sequence.

## Shell Script Contract

The `add-comment.sh` script appends a new comment block to this file.

1. Read the file to find the highest existing `C<N>` ID
2. Increment to get the new ID
3. Append the new comment block with metadata and text
4. Write atomically: write full file to temp, then `mv`

Patterns below use bash features (process substitution). Scripts must use
`#!/usr/bin/env bash`, not `#!/bin/sh`.

### Parsing patterns

Find all comment IDs:
```
grep -oE '^### C[0-9]+' review-comments.md
```

Get the highest comment ID:
```
grep -oE '^### C([0-9]+)' review-comments.md | sort -t'C' -k2 -n | tail -1
```

Extract a specific comment (header + content, up to next header or EOF):
```
awk '
/^### C3$/ { found=1 }
found && /^### C[0-9]/ && $0 != "### C3" { exit }
found { print }
' review-comments.md
```
Includes the `### C3` header, stops before the next `### C<N>`.
Works for first, middle, and last comments. Multi-line form for macOS compatibility.

Find all comments for a specific node:
```
grep -B0 -A1 '^node: 1.1.1$' review-comments.md
```

Find all active comments (two-pass: list all, then exclude deleted):
```
diff <(grep -oE '^### C[0-9]+' review-comments.md) \
     <(grep -B5 '^status: deleted' review-comments.md | grep -oE '^### C[0-9]+') \
  | grep '^< ' | sed 's/^< //'
```
**Note:** This grep-based pattern matches `status: deleted` anywhere in the file,
including inside comment bodies. For accurate results when bodies may contain
metadata-like text, use the awk extraction pattern to isolate metadata before
filtering by status.
