# Docs Reorganization Design

**Date:** 2026-03-14
**Status:** Approved

## Goal

Reorganize the docs/ folder and repo structure so that:
- App runtime artifacts (templates, troubleshoot guides) live alongside other runtime directories at repo root
- Hackweek sprint output is archived separately from ongoing version work
- Each version has a clear home for plans, design, and promoted research
- The current active version is immediately obvious
- Version-independent development guides have a permanent home
- AGENTS.md documents where working files go so all tools route correctly

## Current Structure (Before)

```
docs/
  templates/
    review-tree.md
    review-comments.md
  troubleshoot/
    agent-struggling.md
  guides/
    agent-prompt-design.md
  design/
    agent-prompt-design-decisions.md
  research/
    agent-memory-systems.md
    agentic-restart-patterns.md
    github-pr-review-api.md
    tui-frameworks-comparison.md
  plans/
    v1-implementation.md
    2026-02-26-pr-test-corpus-design.md
  agent-prompt-principles.md
  research-summary.md
  private/
    prompts/
    reconstruction/
  superpowers/
    specs/
```

## Target Structure (After)

```
templates/                               # PROMOTED to root
  review-tree.md
  review-comments.md

troubleshoot/                            # PROMOTED to root
  agent-struggling.md

docs/
  README.md                              # NEW — current version + structure scheme
  guides/                                # permanent, version-independent
    agent-prompt-principles.md           # MOVED from docs/ root
    agent-prompt-design.md               # stays (was docs/guides/)
  hackweek/                              # NEW — Feb 23-26 sprint archive
    research-summary.md                  # MOVED from docs/
    v1-implementation.md                 # MOVED from docs/plans/
    pr-test-corpus-design.md             # MOVED from docs/plans/ (renamed)
    agent-prompt-design-decisions.md     # MOVED from docs/design/
    research/                            # MOVED from docs/research/
      agent-memory-systems.md
      agentic-restart-patterns.md
      github-pr-review-api.md
      tui-frameworks-comparison.md
  v1/                                    # NEW — active version work (created on first use)
    research/                            # promoted high-signal research
  private/                               # unchanged — scratch/investigation
    prompts/
    reconstruction/
```

## File Moves

| Source | Destination |
|---|---|
| `docs/templates/review-tree.md` | `templates/review-tree.md` |
| `docs/templates/review-comments.md` | `templates/review-comments.md` |
| `docs/troubleshoot/agent-struggling.md` | `troubleshoot/agent-struggling.md` |
| `docs/agent-prompt-principles.md` | `docs/guides/agent-prompt-principles.md` |
| `docs/research-summary.md` | `docs/hackweek/research-summary.md` |
| `docs/plans/v1-implementation.md` | `docs/hackweek/v1-implementation.md` |
| `docs/plans/2026-02-26-pr-test-corpus-design.md` | `docs/hackweek/pr-test-corpus-design.md` |
| `docs/design/agent-prompt-design-decisions.md` | `docs/hackweek/agent-prompt-design-decisions.md` |
| `docs/research/agent-memory-systems.md` | `docs/hackweek/research/agent-memory-systems.md` |
| `docs/research/agentic-restart-patterns.md` | `docs/hackweek/research/agentic-restart-patterns.md` |
| `docs/research/github-pr-review-api.md` | `docs/hackweek/research/github-pr-review-api.md` |
| `docs/research/tui-frameworks-comparison.md` | `docs/hackweek/research/tui-frameworks-comparison.md` |
| `docs/superpowers/specs/2026-03-14-docs-reorganization-design.md` | `docs/v1/2026-03-14-docs-reorganization-design.md` |
| `docs/superpowers/plans/2026-03-14-docs-reorganization.md` | `docs/v1/2026-03-14-docs-reorganization-plan.md` |

## New Files

| File | Purpose |
|---|---|
| `docs/README.md` | Current version declaration + docs structure explanation |
| `docs/private/reconstruction/07-docs-reorganization-decision.md` | Decision record for this reorg (already created) |

## Removed Directories

These become empty after moves and should be deleted (including any `.gitkeep` files):
- `docs/templates/`
- `docs/troubleshoot/`
- `docs/plans/`
- `docs/design/`
- `docs/research/`
- `docs/superpowers/`

## Files Requiring Path Updates

These files reference paths that will change:

| File | References to update |
|---|---|
| `AGENTS.md` | Repo structure section, context window hygiene section, NEW file routing convention |
| `README.md` | Architecture section |
| `docs/hackweek/v1-implementation.md` | Internal references to docs/templates/ paths |
| `docs/private/**/*.md` | References to old doc paths (leave as-is — historical artifacts) |

Note: `CLAUDE.md` is a symlink to `AGENTS.md` — updating AGENTS.md covers both.

## AGENTS.md Additions

Add a **File Routing** subsection under Conventions in AGENTS.md covering where working files go:

- **Workbench files** (scratch, investigation, drafts) go in `docs/private/`
- **Designs, specs, plans, and decision records** go in the current version folder (e.g., `docs/v1/`)
- **Curated research** goes in the current version's research subfolder (e.g., `docs/v1/research/`)
- **Example:** Superpowers brainstorming specs go to the current version folder, not `docs/superpowers/specs/`
- **Decision record examples:** design-decisions.md (architecture choices), docs-reorganization-design.md (structural decisions)

The current version is declared in `docs/README.md`.

## Principles

1. **Only high-signal stuff gets checked into version folders.** Private/ is the workbench.
2. **Version folders are the curated gallery.** Plans go directly there. Research gets promoted when it earns its place.
3. **Hackweek files are hackweek files.** Produced during the sprint, archived there. Superseded by new docs.
4. **docs/ root is directories only** (plus README.md). Version folders stand out as obvious destinations.
5. **docs/README.md signals the current version.** The orientation document for anyone opening docs/.
