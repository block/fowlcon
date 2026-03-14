# GitHub PR Review API: Stable References for Inline Comments

**Context:** Fowlcon V1.1 posts reviews with inline comments to GitHub PRs. Getting comment placement right is the hardest technical problem in V1.1.

## The Problem

GitHub's inline comment API requires precise positioning. A misplaced comment destroys reviewer trust. There are two APIs -- one deprecated, one current.

## Deprecated: `position` Parameter (REST v3)

The original API used `position` -- an integer offset from the `@@` hunk header in the diff. This was:
- Fragile (changes when the diff changes)
- Hard to compute (requires parsing unified diff format)
- Only worked with the pull request's HEAD at the time of the API call

**Do not use this.** GitHub's docs mark it as deprecated.

## Current: `line` + `side` Parameters

The modern API uses actual file line numbers:

| Parameter | Type | Description |
|-----------|------|-------------|
| `commit_id` | string | The SHA of the commit to comment on |
| `path` | string | File path relative to repo root |
| `line` | integer | Line number in the file (not the diff) |
| `side` | string | `RIGHT` (new code) or `LEFT` (old/deleted code) |
| `start_line` | integer | For multi-line comments: first line |
| `start_side` | string | Side for the start line |

**The stable reference tuple is:** `commit_sha + path + line + side`

This is what Fowlcon's `review-comments.md` format stores per comment.

## Single-Line vs Multi-Line Comments

**Single-line:** `line` + `side` only. Comments on one line of code.

**Multi-line:** `line` + `side` + `start_line` + `start_side`. Highlights a range. The `line` is the END of the range (where the comment bubble appears), `start_line` is the beginning.

Both lines must be in the same diff hunk. You cannot span across hunks.

## Pending Reviews vs Direct Comments

**Direct comment** (`POST /repos/{owner}/{repo}/pulls/{number}/comments`): Posts immediately. No way to batch or undo.

**Pending review** (recommended for Fowlcon):
1. Create a pending review: `POST /repos/{owner}/{repo}/pulls/{number}/reviews` with `event: "PENDING"`
2. Add comments to it: `POST /repos/{owner}/{repo}/pulls/{number}/comments` (they attach to the pending review)
3. Submit when ready: `POST /repos/{owner}/{repo}/pulls/{number}/reviews/{review_id}/events` with `event: "APPROVE"` or `"COMMENT"` or `"REQUEST_CHANGES"`

Pending reviews are invisible to others until submitted. This aligns with Fowlcon's "explicit affirmative before posting" principle.

## GraphQL Alternative (Recommended)

GraphQL (`gh api graphql`) provides advantages over REST:

- **Incremental comment addition** to pending reviews
- **Per-comment error isolation** -- one bad placement doesn't fail the whole review
- **File-level comments** supported (comment on a file, not a specific line)
- **Pending reviews** invisible until submitted

REST is the fallback. Both go through the same `gh` binary.

## Graceful Degradation

If an inline comment can't be placed (line not in diff, file renamed, hunk boundary crossed):
1. Fall back to a **top-level review comment** with `(intended for path/to/file.java:42)` prefix
2. The review still gets posted -- better imperfect than failed

## SHA Re-Indexing

If the PR HEAD has moved since analysis:
- Comment positions may be wrong (lines shifted, hunks changed)
- Options: re-map positions against the new diff, warn the reviewer, or refuse to post until re-analysis
- Fowlcon detects this by comparing the stored SHA against current PR HEAD

## Sources

- [GitHub REST API: Pull Request Comments](https://docs.github.com/en/rest/pulls/comments)
- [GitHub REST API: Pull Request Reviews](https://docs.github.com/en/rest/pulls/reviews)
- [GitHub GraphQL API: AddPullRequestReviewComment](https://docs.github.com/en/graphql/reference/mutations#addpullrequestreviewcomment)
- [GitHub: Creating a pull request review](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/reviewing-proposed-changes-in-a-pull-request)
