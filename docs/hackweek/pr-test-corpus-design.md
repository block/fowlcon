# PR Test Corpus Design

**Status:** In progress -- decisions captured, open questions remain
**Date:** 2026-02-26

## Goal

Build a real, working test corpus for fowlcon so agent prompts and shell scripts can be tested against realistic PR scenarios with full control over the inputs.

## Core Concept: Fakes, Not Mocks

The corpus is a **real, working Kotlin/Misk HTTP API service** -- not mock data or synthetic diffs. It compiles, runs, and looks like a genuine private service to any agent reviewing its PRs. This follows the "fakes over mocks" testing philosophy: a fully functional implementation that exercises real code paths rather than brittle test doubles coupled to implementation details.

The service is called **Hawksbury** (continuing the bird theme from existing test fixtures). It's a bird sanctuary management API being built by a small team of bird-enthusiast developers with fun personas.

## Architecture

### Subtree with Extraction

The Hawksbury service lives as a git subtree inside `tests/corpus/hawksbury/` in the fowlcon repo. At test time, `git filter-repo --subdirectory-filter tests/corpus/hawksbury` extracts the subtree into an isolated temporary repo. After extraction:

- Files are promoted to repo root (no nested path artifacts)
- All fowlcon-related history is stripped
- No references to the parent repo remain
- The result looks like a standalone Kotlin service

Extraction happens **once per test suite run**, and all tests share the extracted repo.

### Why Subtree + Extraction?

We evaluated three approaches:

| Approach | Isolation | Maintenance | Realism |
|----------|-----------|-------------|---------|
| Subtree inside fowlcon (with extraction) | High (after extraction) | Single repo | High |
| Separate GitHub repo | Perfect | Two repos to coordinate | Highest |
| Git submodule | High | Two repos + submodule friction | High |

The subtree approach gives single-repo simplicity with high isolation after extraction. A separate repo would give perfect isolation but adds coordination overhead and splits maintenance.

### Guarding Against Leakage

- No file in `tests/corpus/hawksbury/` may contain the strings "fowlcon", "review-tree", "review-comments", or "test corpus"
- A CI check validates this on every PR
- The extraction process strips all fowlcon-related git history automatically

## The Hawksbury Service

### Tech Stack

- **Language:** Kotlin
- **Framework:** [Misk](https://github.com/cashapp/misk) (open source microservice framework)
- **Build:** Gradle with Kotlin DSL
- **Dependencies:** Public only (Maven Central)

### Narrative History

The git history tells a lifelike story of a small team building a service. Commits read like real development work -- initial setup, add endpoints, add tests, expand features. This is not a flat collection of files; it's a project with an arc.

The main branch is **immutable after initial creation**. New test scenarios branch off at natural points in the story. This ensures existing scenario diffs never change when new scenarios are added.

### Personas

PR authors and reviewers are bird-themed personas with consistent identities in commit messages and PR descriptions. (Specific personas TBD during implementation.)

## Test Scenarios

Each scenario is a branch representing a PR that exercises specific fowlcon review behaviors. Target: ~10 scenarios covering:

1. **Mechanical + novel mix** -- Many files with the same pattern (variation/repeat) plus some novel logic. The core fowlcon use case.
2. **Backpressure trigger** -- Too many interleaved concepts, high file count, no clear grouping. Tests that the agent would push back.
3. **Small focused PR** -- 2-5 files, single concept. Tests the simple path.
4. **Rename-heavy PR** -- Files moved/renamed. Tests file tracking across renames.
5. **Delete-only PR** -- Removing dead code. Tests handling of deletion-only diffs.
6. **New feature PR** -- All new files, no modifications. Tests new-file-only analysis.
7. **Cross-cutting concern** -- Changes that touch many layers (API, service, data, tests) for one feature.
8. **Test-only PR** -- Only test files changed. Tests classification of test code.
9. **Description mismatch** -- PR description makes claims that contradict the diff. Tests description verification.
10. **Multi-concept PR** -- Several unrelated changes bundled together (the "kitchen sink" PR).

Each scenario includes:
- A branch with realistic commits
- A PR description with intentional claims (correct, incorrect, and omitted) for testing description verification
- Expected structural properties (concept count ranges, variation detection, coverage expectations)

## Testing Modes

### Blind Mode
The agent sees only the extracted repo. No indication it's a test. Most realistic.

### Aware Mode
The agent prompt includes a note: "You may recognize this as a test fixture. Your job is to produce the same output you would for a real PR. Be representative." Useful for debugging and prompt development.

Both modes need testing to understand behavioral differences.

## Open Questions

### How does the agent receive PR data without GitHub?

This is the biggest unresolved design question. In production, fowlcon takes a GitHub PR URL and fetches data via `gh` CLI. The test corpus has no GitHub PRs. Options under investigation:

1. **Local mode in the orchestrator** -- Support a local repo path + base/head refs instead of a GitHub URL. Useful beyond testing (pre-push review, non-GitHub hosts).
2. **Mock the `gh` CLI** -- A shell wrapper that returns pre-generated data for specific subcommands.
3. **Push extracted repo to GitHub** -- Create real PRs on a real GitHub repo after extraction.
4. **Pre-generated diff files** -- Each scenario ships with a `.diff` and `description.md`.

Research needed on: what data the orchestrator actually consumes from GitHub, format differences between `gh pr diff` and `git diff`, and what other agentic tools do for local/offline input.

### What defines "correct" output per scenario?

Options:
- **Structural assertions** -- Must have N top-level nodes, must detect variation, must achieve 100% coverage
- **Golden files** -- Full expected review-tree.md per scenario (brittle but precise)
- **LLM-as-judge** -- Grade quality using a rubric (flexible but non-deterministic)
- **Tiered** -- Structural assertions for CI, golden files for nightly, LLM-as-judge for releases

### What invokes the agent in tests?

- True E2E (call Claude API, $5-20/run) -- most realistic, most expensive
- Structural assertions only ($0/run) -- test scripts and formats, not agent behavior
- Deterministic replay (record once, replay free) -- test agent logic without API calls
- Tiered approach matching the test pyramid

### Build infrastructure weight

The working Kotlin app requires JDK + Gradle in CI. This adds weight to a repo that's currently markdown + bash. Need to ensure this doesn't slow down unrelated CI jobs (separate workflow or conditional triggers).

### Corpus evolution

When main is immutable, how do we handle:
- Bug fixes in Hawksbury code needed for new scenarios
- Dependency updates for security
- Growing the app for more complex scenarios

Current thinking: the story continues forward. New commits extend the narrative. Old scenario branches remain anchored to their base points.

## Relationship to Test Pyramid

The corpus serves multiple tiers:

| Tier | What | Cost | Uses Corpus? |
|------|------|------|-------------|
| Structural (bats) | Format/script validation | $0 | Yes -- realistic fixtures |
| Smoke (cheap model) | Output structure | $0.01-0.10 | Yes -- scenario diffs |
| Golden (full model) | Review quality | $2-5 | Yes -- full agent runs |
| E2E (real PRs) | Integration | $10-50 | Yes -- the whole point |

## Next Steps

1. Resolve the "PR data without GitHub" question (research in progress)
2. Finalize scenario list and structural expectations
3. Design the Hawksbury app (endpoints, data model, project structure)
4. Implement the initial codebase on main
5. Create scenario branches one at a time
6. Build the extraction + test harness
7. Add CI integration
