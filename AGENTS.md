# Fowlcon -- Agent Instructions

This file is read by AI coding agents (Claude Code, Amp, Cursor, Gemini, etc.) when working in this repository.

## What This Project Is

Fowlcon is an agentic code review tool. The "code" in this repo is primarily **markdown prompt files** and **shell scripts**, not a traditional application. The prompts define agent behavior; the scripts manage review state.

## Repository Structure

```
commands/
  review_pr.md              # Orchestrator command (Opus) -- the main entry point

agents/
  concept-researcher.md     # Focused investigation agent (Sonnet)
  codebase-locator.md       # File discovery (Sonnet, based on RPI)
  codebase-analyzer.md      # Code understanding (Sonnet, based on RPI)
  codebase-pattern-finder.md # Pattern matching (Sonnet, based on RPI)
  coverage-checker.md       # Completeness verification (Haiku)

scripts/
  update-node-status.sh     # Atomic tree state updates
  add-comment.sh            # Comment capture with line context
  coverage-report.sh        # Coverage summary from tree
  check-tree-quality.sh     # Structural quality validation

templates/
  review-tree.md            # Format spec: the tree IS the state
  review-comments.md        # Format spec: comment store

troubleshoot/
  agent-struggling.md       # Diagnostic guide loaded on agent failure

tests/
  scripts/                  # bats-core tests for shell scripts
  formats/                  # Sample format files for validation

docs/
  guides/                   # Version-independent development guidance
  hackweek/                 # Feb 23-26 2026 sprint archive
  v1/                       # Active V1 work: plans, designs, decision records
  private/                  # Investigation workbench (scratch and reconstruction work)
```

## Conventions

### Prompts (commands/ and agents/)

- All prompts are markdown with YAML frontmatter (`name`, `description`, `tools`, `model`)
- Commands use `opus` model; agents use `sonnet` or `haiku`
- Agents are documentarians -- they describe what they find, never critique or suggest improvements
- Agent prompts receive context inline (never as file path references)
- Keep each agent focused on just its component. If an agent is doing two things, it should probably be two agents.

### Shell Scripts (scripts/)

- All scripts write atomically: temp file + `mv` (POSIX rename)
- Single-writer assumption: only the orchestrator triggers writes, through these scripts
- Scripts validate inputs (reject invalid statuses, missing files)
- Scripts use `set -euo pipefail`. **Grep hazard:** `grep` returns exit 1 when no matches, which kills the script in a pipeline. Use `|| true` on grep pipelines where zero matches is valid: `VAR=$(grep PATTERN file | ... || true)`
- Scripts ship with the tool and are installed alongside prompts

### State Files

- `review-tree.md` is the critical format -- the tree IS the state. Everything parses, renders, or mutates this file.
- `review-comments.md` stores comments with full metadata (text, node, file, lines, diff context, inline/top-level)
- All state files include PR HEAD SHA at time of creation
- Formats must be human-readable, LLM-parseable, and forward-compatible across versions

### Testing

- Shell scripts: TDD with bats-core. Write the failing test first.
- Agent prompts: Iterate against real PRs. Verify output structure and coverage.
- Tree quality: Structural assertions (all lines mapped, <= 7 top-level concepts, patterns collapsed)

### Principles

See the 10 core principles in README.md. Key ones for contributors:

- **Completeness over speed** -- don't add shortcuts that skip coverage checking
- **Facts first, opinions labeled** -- agent prompts must not embed quality judgments unless clearly tagged as opt-in opinions
- **Opinionated defaults** -- prefer good defaults over configuration knobs
- **Transparent memory** -- all persistent state changes must be proposed to the customer and approved

### Context Window Hygiene

Files in this repo are loaded into LLM context windows during operation. Stale references to old versions, deprecated features, or forward-looking spec commentary waste context tokens and can confuse agents. When implementing a new version, remove or replace references to the previous version's planning notes.

When adding forward-looking version notes to files, add an entry here so future agents know to clean them up.

**Known examples:**
- `templates/review-comments.md` has a **V1.1 Posting Compatibility** section (~50 lines) with GitHub API mapping, GraphQL recommendations, and graceful degradation strategy. This is forward-looking spec commentary for V1.0. When V1.1 posting is implemented, replace this section with actual implementation docs.

### Commits

- One logical change per commit
- Descriptive messages explaining why, not just what
- Every task ends with: verify, document, commit

### Doc File Routing

Working files go to predictable locations based on their type:

- **Workbench files** (scratch, investigation, drafts) go in `docs/private/`
- **Designs, specs, plans, and decision records** go in the current version folder (e.g., `docs/v1/`). Examples: implementation plans, design-decisions docs, reorg specs.
- **Curated research** goes in the current version's `research/` subfolder (e.g., `docs/v1/research/`). Research starts in `docs/private/` and gets promoted when it's high-signal enough to keep.
- **Version-independent guides** stay in `docs/guides/`

The current version is declared in `docs/README.md`.

Tools may try to write specs or plans to their own default locations (e.g., `docs/superpowers/specs/`). Redirect these to the appropriate folder.
