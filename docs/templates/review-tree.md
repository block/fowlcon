# Review Tree Format Specification

This document defines the `review-tree.md` format -- the single source of truth for a
Fowlcon code review session. The tree IS the state: no separate state file exists.

## Header

Every review tree starts with a metadata header:

```
# Review Tree: <PR title>

| Field       | Value |
|-------------|-------|
| PR          | <owner/repo#number> |
| HEAD        | <full commit SHA at time of analysis> |
| Tree Built  | <ISO 8601 timestamp> |
| Updated     | <ISO 8601 timestamp> |
```

The HEAD SHA anchors all analysis. If the PR advances past this SHA, the tree is stale.

## Tree

The tree section follows the header. It contains the hierarchical node structure
ending at the `## Description Verification` heading.

### Node Format

Each node is a single-line entry with a predictable structure:

```
- [<status>] <id>. <title> {<flags>}
```

Where:
- **status**: One of `pending`, `reviewed`, `accepted` (mutually exclusive)
- **id**: Dot-separated numeric identifier (see ID Scheme below)
- **title**: Human-readable concept name
- **flags**: Space-separated flags in curly braces. Currently defined:
  - `comment` -- this node has associated comments in review-comments.md
  - `variation` -- this is a variation node: children are instances of the
    same pattern (see Node Types below)
  - `repeat` -- this node follows the same structural pattern as its example
    sibling(s) under a variation parent. Has files but no subtree.

Flags are optional. If no flags, omit the `{...}` entirely.

### Node Types

**Concept node** (default, no flag): Children are different aspects of the same
thing. The parent's concept is broken down into sub-concepts.

```
- [pending] 1. Core guard mechanism
  - [pending] 1.1. LegacyEndpointGuard class
  - [pending] 1.2. Test infrastructure
```

**Variation node** (`{variation}` flag): Children are practically identical
instances of a pattern. First child(ren) are detailed examples with their own
subtrees. Remaining children use `{repeat}` to indicate "same structure as the
example." Each repeat child is its own node with its own status and files, so
individual instances can be commented on or reviewed separately.

```
- [accepted] 2. Active guard usage {variation}
  - [accepted] 2.1. Example: CloseAccountAppApi
    - [accepted] 2.1.1. Import added
      files:
      - .../CloseAccountAppApi.java L3-3 (+1/-0)
    - [accepted] 2.1.2. Field injection added
      files:
      - .../CloseAccountAppApi.java L18-20 (+3/-0)
    - [accepted] 2.1.3. checkEndpoint() call
      files:
      - .../CloseAccountAppApi.java L35-36 (+1/-0)
  - [accepted] 2.2. ActivateCardAppApi {repeat}
    files:
    - .../ActivateCardAppApi.java L3-3 (+1/-0)
    - .../ActivateCardAppApi.java L18-20 (+3/-0)
    - .../ActivateCardAppApi.java L35-36 (+1/-0)
  - [accepted] 2.3. AddBankAccountAppApi {repeat}
    files:
    - .../AddBankAccountAppApi.java L5-5 (+1/-0)
    - .../AddBankAccountAppApi.java L22-24 (+3/-0)
  ... (each handler is its own node)
```

Variation nodes can nest. A variation child can itself be a variation node with
its own examples and repeats -- useful when a pattern has sub-variations (e.g.,
most handlers need 3 lines but some need 4 due to an extra import).

### ID Scheme

Node IDs are dot-separated numbers with no depth limit:

| Level | Format | Examples |
|-------|--------|----------|
| Top-level | `N` | `1`, `2`, `3` |
| Second level | `N.N` | `1.1`, `1.2`, `2.1` |
| Third level | `N.N.N` | `1.1.1`, `1.1.2`, `2.1.3` |
| Deeper | `N.N.N.N...` | `1.1.1.1`, etc. |

IDs contain only digits `0-9` and dots `.`. Each ID is followed by a period
and a space (`. `), which anchors regex matching. When matching IDs in regex,
dots within the ID must be escaped: `1\.2\.1\.` matches node `1.2.1`.

### Node Block Structure

Within a node's indented block, elements appear in this order (all optional):

1. `context:` -- orchestrator's explanation (see Context below)
2. `files:` -- file mappings (leaf nodes only, see File Mappings below)
3. Child nodes -- `- [status] ...`

Four line types appear within a node's indented block:
- `context:` -- block delimiter for the orchestrator's explanation
- `files:` -- block delimiter for file mappings
- Lines starting with a path -- file entries (under `files:`)
- Lines starting with `[status]` -- child nodes

### Context

Any node can have an optional `context:` block -- the orchestrator's explanation
of what this concept is and why it matters. This is the tour guide's voice.

Format: `context:` followed by a YAML-style block scalar (`|`), with indented text.

```
- [reviewed] 1.1.2. Graceful fallback on missing config
  context: |
    The catch block defaults to SILENT if the LaunchDarkly flag is not
    configured. Safe default -- a misconfigured flag never breaks an
    endpoint in production. But swallows all exceptions.
  files:
  - core/src/.../LegacyEndpointGuard.java L57-72 (+15/-0)
```

For short context, a single line without the block scalar is fine:

```
- [reviewed] 4.1. FetchCustomerDataInternalApi
  context: "Author states: CDS T0 API, too critical to add guard"
```

Benefits: resuming sessions doesn't re-generate explanations, TUI can render
without calling the agent, posted reviews can include context, and it's the
record of what was presented to the customer.

### Hierarchy

Indentation (2 spaces per level) encodes parent-child relationships:

```
- [pending] 1. Core guard mechanism
  - [pending] 1.1. LegacyEndpointGuard class
    - [pending] 1.1.1. LaunchDarkly integration
    - [pending] 1.1.2. Graceful fallback behavior
    - [pending] 1.1.3. SILENT/LOG/BLOCK modes
    - [pending] 1.1.4. Dependency injection pattern
  - [pending] 1.2. Test infrastructure
```

### Status Transitions

Confidence hierarchy: `reviewed` > `accepted` > `pending`

```
pending -> reviewed     (customer examined this in detail -- highest confidence)
pending -> accepted     (customer trusts the pattern -- lower confidence)
reviewed -> accepted    (rare downgrade -- customer decides they over-examined)
accepted -> reviewed    (upgrade -- customer wants to verify what they trusted)
Any -> pending          (reset -- customer changed their mind)
```

Comment flag is independent: added when a comment is captured, never removed by
status changes.

## File Mappings

File mappings appear **only on leaf nodes**. A non-leaf node's coverage is the
union of all file references in its subtree -- it propagates upward automatically.
Root coverage = union of everything = the full diff.

File entries are per diff hunk, not per file -- a single file with multiple
changed hunks gets multiple entries. This is critical for comment anchoring.

```
- [reviewed] 1.1.3. SILENT/LOG/BLOCK modes {comment}
  files:
  - core/src/.../LegacyEndpointGuard.java L45-80 (+35/-0)
  - core/src/.../LegacyEndpointMode.java L1-28 (+28/-0)
```

Every diff hunk must be listed explicitly under at least one leaf node. Do not
summarize with "... and N more". The `context:` block communicates scale;
the file list is the proof of coverage.

A diff hunk can appear under multiple leaf nodes if it's relevant to multiple
concepts. Coverage checking means every hunk appears **at least once**, not
exactly once.

Nodes whose subtree contains zero file entries are implicitly not in the diff.
The `context:` block explains why the node exists (e.g., exclusions mentioned
in the PR description).

### File Entry Format

```
<path> L<start>-<end> (<change>)
```

Where:
- **path**: File path relative to repo root
- **L\<start\>-\<end\>**: Line range in the file that this hunk covers
- **change**: One of:
  - `(+N/-M)` -- N lines added, M lines deleted
  - `(+N)` -- additions only (shorthand for +N/-0)
  - `(-M)` -- deletions only (shorthand for +0/-M)

## Description Verification

A dedicated section after the tree records how PR description claims map to code:

```
## Description Verification

| # | Claim | Status | Evidence |
|---|-------|--------|----------|
| 1 | "194 inactive handlers get active guard" | verified | 194 files matched in node 2 |
| 2 | "2 exclusions" | verified | Neither appears in diff; noted in node 4 |
| 3 | <something in diff not in description> | undocumented | Node 5 not in PR description |
```

Status values: `verified`, `unverified`, `contradicted`, `undocumented`
- **verified**: claim matches code evidence
- **unverified**: claim could not be confirmed (not enough evidence)
- **contradicted**: claim conflicts with code evidence
- **undocumented**: code change exists with no corresponding description claim

## Coverage

A final section confirms file coverage:

```
## Coverage

Total files in diff: <N>
Files mapped to tree: <N>
Unmapped files: <list or "none">
```

## Shell Script Contract

Scripts that mutate this file MUST:

1. Find nodes by regex: `^\s*- \[<status>\] <id>\.`
   - Status match: `\[(pending|reviewed|accepted)\]`
   - ID match: exact string with dots escaped (e.g., `1\.2\.1`)
2. Update status in-place: replace the status keyword between brackets
3. Add/remove flags: append or remove tokens within `{...}` at end of line
4. Write atomically: temp file + `mv`

### Regex patterns for scripts

Find node by ID (e.g., id="1.2.1"):
```
^(\s*- \[)(pending|reviewed|accepted)(\] 1\.2\.1\.)
```

Update status (capture groups allow replacement of group 2):
```
sed -E 's/^(\s*- \[)(pending|reviewed|accepted)(\] 1\.2\.1\.)/\1reviewed\3/'
```

Add comment flag (if no flags exist):
```
sed -E '/^\s*- \[.*\] 1\.2\.1\./ { /\{/! s/$/ {comment}/ }'
```

Add comment flag (if flags already exist):
```
sed -E '/^\s*- \[.*\] 1\.2\.1\./ s/\}/ comment}/'
```
