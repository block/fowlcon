# Fowlcon

**Foul code + fowl (bird) + falcon (the duckhawk).** An agentic code review tool that walks reviewers through PRs with thoroughness and competent backpressure.

## The Problem

AI coding agents are flooding review queues with PRs that are larger, more frequent, and structurally different from human-authored work. A single agent session can produce changes spanning hundreds of files -- mixing mechanical changes (the same pattern applied repetitively) with novel logic requiring genuine human judgment.

Today's review tools offer no way to distinguish between the two. GitHub shows a flat file list. 390 files of the same mechanical transformation look identical to 390 files of unrelated changes.

Reviewers have three bad options: spend hours reading every file (doesn't scale), rubber-stamp and hope (dangerous), or push back with vague "please split this" comments that feel obstructive and lack specifics.

## The Solution

Fowlcon gives reviewers two capabilities they lack today:

1. **Efficiently process large PRs** by collapsing mechanical changes and organizing novel logic into reviewable concepts
2. **Push back with precision** -- not "this PR is too big" but "here are the 7 logical concepts, here's how they interleave across files, and here's why that's hard to review"

You give Fowlcon a PR link. It analyzes the code, builds a logical breakdown of the changes into a concept tree, and walks you through each concept interactively. Every changed line is accounted for. Nothing gets silently missed.

### Example

A 390-file PR adding a feature guard to RPC handlers collapses into 5 reviewable concepts:

```
PR: Add RoostGuard for roost lifecycle management

1. Core: The guard mechanism
   1.1. RoostGuard class
        1.1.1. Feature flag integration
        1.1.2. SILENT/CHIRP/BLOCK mode switching
   1.2. Test infrastructure

2. Active guard usage {variation}
   2.1. Example: CloseNestAppApi
        2.1.1. Import added
        2.1.2. Field injection added
        2.1.3. checkRoost() call
   ... 193 more following same pattern {repeat}

3. Commented-out guard {variation}
   3.1. Example: GetFlockProfileAppApi
   ... 195 more following same pattern {repeat}

4. Exclusions (not in diff -- context explains why)

5. CLAUDE.md update (meta)
```

You review the guard mechanism in detail. You confirm one example of the active guard pattern, then accept the remaining 193 as a batch. The whole review takes minutes, not hours. Description claims are verified against the actual diff in a separate table.

## How It Works

Fowlcon is an agentic tool built as markdown prompts -- it runs inside Claude Code, Amp, or any platform that supports agent commands.

```
/review-pr https://github.com/org/repo/pull/123
```

The orchestrator (Opus) analyzes the PR by spawning concept researchers (Sonnet) that investigate different areas of the code. It builds a review tree, verifies the PR description against the actual diff, and checks that every changed line is covered.

The walkthrough is conversational -- you confirm concepts you understand, short-circuit patterns with "I get it! Accept the rest," and dig deeper where you have questions. Every node starts as pending until you make a decision.

If the tree reveals too much complexity, Fowlcon helps you send the author specific structural feedback -- the concept map itself becomes the review.

### The Review Tree

The tree uses two node types:

- **Concept nodes** break a change into sub-concepts (e.g., "guard mechanism" has "class," "modes," "DI pattern")
- **Variation nodes** collapse repeated patterns (e.g., 194 handlers getting the same 3-line change). One detailed example, the rest marked as `{repeat}`.

Each node has a `context:` block -- the orchestrator's explanation of what the concept is and why it matters. This is the guide walking you through the code, stored in the tree so sessions can resume without re-explaining.

File mappings are per diff hunk with line ranges, anchoring every changed line to a concept. Coverage means every hunk appears at least once.

### Core Principles

These guide both the product and contributions to the project:

1. **Completeness over speed.** Every changed line maps to a concept. Pending nodes are flagged before finalization. Nothing gets silently missed.
2. **The customer is fallible but trusted.** We're guardrails, not gatekeepers. Default to "pending." Make it easy to go back. Protect reviewers from rushing.
3. **The author must prove through code.** Description claims are verified against the diff. Discrepancies are surfaced. The code is the truth.
4. **Facts first, opinions labeled.** The core experience is factual. Qualitative judgments are opt-in and always clearly tagged.
5. **Complexity, not size.** The review tree is organized by logical concepts, not files. 50 files following one pattern is one concept with examples. The intelligence is in the grouping.
6. **Customer collaboration.** When a PR is too complex, Fowlcon helps you articulate why -- with specific, actionable structural feedback. The reviewer's domain knowledge makes the review better.
7. **Explicit consent for all external actions.** Nothing gets posted without an explicit affirmative. The review exists locally until the reviewer says "post it."
8. **Accuracy, truth, and facts.** If something was missed, flag it. If the agent is uncertain, say so. Admitting a gap is always better than papering over it.
9. **Transparent memory.** All learned preferences are proposed to the reviewer and require approval before being saved. The reviewer always knows what the tool is learning.
10. **Opinionated defaults.** The tool ships with defaults we believe are good for most cases. It should just work without configuration. Reviewers adjust through use, not upfront setup.

### Node States

As you walk through the tree, each concept gets a status:

- **Pending** -- no decision yet (default)
- **Reviewed** -- you looked at it in detail (highest confidence)
- **Accepted** -- you trust the pattern holds ("I get it! Accept the rest.")
- **+ Comments** -- independent flag, any status can have comments

Confidence hierarchy: reviewed > accepted > pending.

## Installation

```bash
# Clone the repo
git clone https://github.com/block/fowlcon.git

# Run the install script
cd fowlcon && ./scripts/install
```

This copies agent and command files to `~/.claude/` (or your platform's agent directory).

## Architecture

```
commands/
  review_pr.md              # Orchestrator (Opus) -- drives the review

agents/
  concept-researcher.md     # Investigates specific concepts (Sonnet)
  codebase-locator.md       # Finds relevant files (Sonnet)
  codebase-analyzer.md      # Understands code (Sonnet)
  codebase-pattern-finder.md # Finds patterns (Sonnet)
  coverage-checker.md       # Verifies completeness (Haiku)

scripts/
  update-node-status.sh     # Atomic tree state updates
  add-comment.sh            # Comment capture with line context
  coverage-report.sh        # Coverage summary from tree
  check-tree-quality.sh     # Structural quality validation

templates/
  review-tree.md            # Format spec: the tree IS the state
  review-comments.md        # Format spec: comment store, V1.1 posting

troubleshoot/
  agent-struggling.md       # Diagnostic guide loaded on agent failure

docs/
  guides/                   # Version-independent development guidance
  hackweek/                 # Feb 23-26 2026 sprint archive
  v1/                       # Active V1 plans, designs, decision records
  private/                  # Investigation workbench (gitignored)

tests/
  formats/                  # Parsing tests for format specs (bats-core)
  scripts/                  # Unit tests for shell scripts (bats-core)
```

State lives in markdown files. The review tree IS the state -- a single file with embedded statuses, context blocks, and per-hunk file mappings. Shell scripts enforce atomic writes. Format specifications define the contract between the orchestrator, scripts, and future UI implementations.

## Data

```
~/.code-review-agent/
  user-hints.md             # Persistent preferences (survives cache clears)

~/.cache/code-review-agent/
  org-repo-1234/            # Per-PR review data (ephemeral)
    review-tree.md          # The review tree (state)
    review-comments.md      # Captured comments
    analysis.md             # Raw research findings
```

Per-PR data persists across sessions. You can come back to a review later and pick up where you left off.

## Status

Fowlcon is under active development. Phase 1 (formats + scripts) is in progress.

## Acknowledgments

Fowlcon's architecture is informed by patterns from:
- Other researching subagent architectures -- command/agent structure and research sub-agent patterns
- [Superpowers](https://github.com/obra/superpowers) -- anti-rationalization techniques and skills architecture

## Project Resources

| Resource | Description |
|----------|-------------|
| [CODEOWNERS](./CODEOWNERS) | Project lead(s) |
| [GOVERNANCE.md](./GOVERNANCE.md) | Project governance |
| [LICENSE](./LICENSE) | Apache License, Version 2.0 |
