# Docs Reorganization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize docs/ so app runtime artifacts live at repo root, hackweek output is archived, each version has a clear home, and AGENTS.md documents file routing.

**Architecture:** File moves via `git mv`, new files via write, content updates to AGENTS.md/README.md, path sweep at end. No code changes — this is entirely structural.

**Tech Stack:** git, bash, grep

**Spec:** `docs/v1/2026-03-14-docs-reorganization-design.md` (moves there as part of this plan)

---

## Chunk 1: File Moves

### Task 1: Promote app runtime directories to repo root

**Files:**
- Move: `docs/templates/review-tree.md` → `templates/review-tree.md`
- Move: `docs/templates/review-comments.md` → `templates/review-comments.md`
- Move: `docs/troubleshoot/agent-struggling.md` → `troubleshoot/agent-struggling.md`
- Delete: `docs/templates/.gitkeep`, `docs/troubleshoot/.gitkeep`

- [ ] **Step 1: Create root directories and move files**

```bash
mkdir -p templates troubleshoot
git mv docs/templates/review-tree.md templates/review-tree.md
git mv docs/templates/review-comments.md templates/review-comments.md
git mv docs/troubleshoot/agent-struggling.md troubleshoot/agent-struggling.md
```

- [ ] **Step 2: Clean up empty directories**

```bash
git rm -f docs/templates/.gitkeep docs/troubleshoot/.gitkeep
```

Git will remove the now-empty directories automatically.

- [ ] **Step 3: Verify**

```bash
ls templates/
# Expected: review-comments.md  review-tree.md
ls troubleshoot/
# Expected: agent-struggling.md
ls docs/templates/ 2>/dev/null && echo "ERROR: still exists" || echo "OK: removed"
ls docs/troubleshoot/ 2>/dev/null && echo "ERROR: still exists" || echo "OK: removed"
```

- [ ] **Step 4: Commit**

```bash
git add templates/ troubleshoot/
git commit -m "refactor: promote templates/ and troubleshoot/ to repo root

These are app runtime artifacts (format specs, agent failure guides),
not project documentation. They belong alongside agents/, commands/,
scripts/ as peer directories."
```

---

### Task 2: Move hackweek sprint output to docs/hackweek/

**Files:**
- Move: `docs/research-summary.md` → `docs/hackweek/research-summary.md`
- Move: `docs/plans/v1-implementation.md` → `docs/hackweek/v1-implementation.md`
- Move: `docs/plans/2026-02-26-pr-test-corpus-design.md` → `docs/hackweek/pr-test-corpus-design.md`
- Move: `docs/design/agent-prompt-design-decisions.md` → `docs/hackweek/agent-prompt-design-decisions.md`
- Move: `docs/research/*.md` → `docs/hackweek/research/*.md`
- Delete: `docs/plans/.gitkeep`, `docs/design/.gitkeep`, `docs/research/.gitkeep` (if they exist)

- [ ] **Step 1: Create hackweek directory structure**

```bash
mkdir -p docs/hackweek/research
```

- [ ] **Step 2: Move files**

```bash
git mv docs/research-summary.md docs/hackweek/research-summary.md
git mv docs/plans/v1-implementation.md docs/hackweek/v1-implementation.md
git mv docs/plans/2026-02-26-pr-test-corpus-design.md docs/hackweek/pr-test-corpus-design.md
git mv docs/design/agent-prompt-design-decisions.md docs/hackweek/agent-prompt-design-decisions.md
git mv docs/research/agent-memory-systems.md docs/hackweek/research/agent-memory-systems.md
git mv docs/research/agentic-restart-patterns.md docs/hackweek/research/agentic-restart-patterns.md
git mv docs/research/github-pr-review-api.md docs/hackweek/research/github-pr-review-api.md
git mv docs/research/tui-frameworks-comparison.md docs/hackweek/research/tui-frameworks-comparison.md
```

- [ ] **Step 3: Clean up empty directories**

```bash
git rm -f docs/plans/.gitkeep docs/design/.gitkeep docs/research/.gitkeep 2>/dev/null || true
```

- [ ] **Step 4: Verify**

```bash
ls docs/hackweek/
# Expected: agent-prompt-design-decisions.md  pr-test-corpus-design.md  research/  research-summary.md  v1-implementation.md
ls docs/hackweek/research/
# Expected: agent-memory-systems.md  agentic-restart-patterns.md  github-pr-review-api.md  tui-frameworks-comparison.md
ls docs/plans/ 2>/dev/null && echo "ERROR" || echo "OK: removed"
ls docs/design/ 2>/dev/null && echo "ERROR" || echo "OK: removed"
ls docs/research/ 2>/dev/null && echo "ERROR" || echo "OK: removed"
```

- [ ] **Step 5: Commit**

```bash
git add docs/hackweek/
git commit -m "refactor: archive hackweek sprint output to docs/hackweek/

All docs produced during the Feb 23-26 sprint move here. These are
V1-alpha artifacts that will be superseded by new V1 docs informed
by reconstruction research."
```

---

### Task 3: Move remaining files to final locations

**Files:**
- Move: `docs/agent-prompt-principles.md` → `docs/guides/agent-prompt-principles.md`
- Move: `docs/superpowers/specs/2026-03-14-docs-reorganization-design.md` → `docs/v1/2026-03-14-docs-reorganization-design.md`
- Move: `docs/superpowers/plans/2026-03-14-docs-reorganization.md` → `docs/v1/2026-03-14-docs-reorganization-plan.md`

- [ ] **Step 1: Create v1 directory and move files**

```bash
mkdir -p docs/v1
git mv docs/agent-prompt-principles.md docs/guides/agent-prompt-principles.md
git mv docs/superpowers/specs/2026-03-14-docs-reorganization-design.md docs/v1/2026-03-14-docs-reorganization-design.md
git mv docs/superpowers/plans/2026-03-14-docs-reorganization.md docs/v1/2026-03-14-docs-reorganization-plan.md
```

- [ ] **Step 2: Verify superpowers directory is empty, then remove**

```bash
# After git mv, only empty dirs should remain. Verify before removing.
ls docs/superpowers/specs/ 2>/dev/null && echo "ERROR: specs/ not empty" || true
ls docs/superpowers/plans/ 2>/dev/null && echo "ERROR: plans/ not empty" || true
rmdir docs/superpowers/specs docs/superpowers/plans docs/superpowers 2>/dev/null || echo "WARN: dirs not empty, check manually"
```

- [ ] **Step 3: Verify**

```bash
ls docs/guides/
# Expected: agent-prompt-design.md  agent-prompt-principles.md
ls docs/v1/
# Expected: 2026-03-14-docs-reorganization-design.md  2026-03-14-docs-reorganization-plan.md
ls docs/superpowers/ 2>/dev/null && echo "ERROR" || echo "OK: removed"
```

- [ ] **Step 4: Commit**

```bash
git add docs/guides/ docs/v1/
git commit -m "refactor: move principles to guides/, specs and plans to v1/

Principles doc joins the design guide in docs/guides/ (version-independent).
Spec and plan for this reorg move to docs/v1/ (current version work)."
```

---

## Chunk 2: New Files and Content Updates

### Task 4: Create docs/README.md

**Files:**
- Create: `docs/README.md`

- [ ] **Step 1: Write docs/README.md**

```markdown
# Docs

**Current version: V1**

Plans, designs, decision records, and curated research for V1 go in `v1/`.

## Structure

| Directory | Purpose |
|-----------|---------|
| `guides/` | Version-independent development guidance (prompt principles, design guide) |
| `hackweek/` | Archive of the Feb 23-26 2026 sprint that created Fowlcon's foundation |
| `v1/` | Active V1 work: plans, designs, decision records, promoted research |
| `private/` | Investigation workbench: scratch files, drafts, reconstruction work |

Future versions (v1.001/, v1.01/, v1.1/) get their own directories as work begins.

## Where files go

- **Plans, designs, specs, decision records** go directly in the current version folder
- **Research** starts in `private/` and gets promoted to the version's `research/` subfolder when it's high-signal enough to keep
- **Scratch work and investigation** stays in `private/`

See AGENTS.md (repo root) for the full file routing conventions.
```

- [ ] **Step 2: Commit**

```bash
git add docs/README.md
git commit -m "docs: add docs/README.md with current version and structure scheme"
```

---

### Task 5: Update AGENTS.md

**Files:**
- Modify: `AGENTS.md`

Note: `CLAUDE.md` is a symlink to `AGENTS.md` — updating one covers both.

- [ ] **Step 1: Update the repo structure section**

Replace the code block in the `## Repository Structure` section (lines 11-35) with:

````markdown
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
````

- [ ] **Step 2: Add File Routing subsection under Conventions**

Add after the existing Commits subsection:

```markdown
### File Routing

Working files go to predictable locations based on their type:

- **Workbench files** (scratch, investigation, drafts) go in `docs/private/`
- **Designs, specs, plans, and decision records** go in the current version folder (e.g., `docs/v1/`). Examples: implementation plans, design-decisions docs, reorg specs.
- **Curated research** goes in the current version's `research/` subfolder (e.g., `docs/v1/research/`). Research starts in `docs/private/` and gets promoted when it's high-signal enough to keep.
- **Version-independent guides** stay in `docs/guides/`

The current version is declared in `docs/README.md`.

Tools that default to other locations (e.g., superpowers brainstorming writes specs to `docs/superpowers/specs/`) should be redirected to the current version folder.
```

- [ ] **Step 3: Update Context Window Hygiene section**

The known example references `docs/templates/review-comments.md`. Update to `templates/review-comments.md`.

- [ ] **Step 4: Verify CLAUDE.md symlink still works**

```bash
ls -la CLAUDE.md
# Expected: CLAUDE.md -> AGENTS.md
head -1 CLAUDE.md
# Expected: # Fowlcon -- Agent Instructions
```

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md with new repo structure and file routing conventions"
```

---

### Task 6: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Architecture section**

Replace the code block in the `## Architecture` section (lines 118-143) with:

````markdown
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

tests/
  formats/                  # Parsing tests for format specs (bats-core)
  scripts/                  # Unit tests for shell scripts (bats-core)
```
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README.md architecture to reflect new repo structure"
```

---

### Task 7: Update internal path references in moved files

**Files:**
- Modify: `docs/hackweek/v1-implementation.md`

- [ ] **Step 1: Find and update stale paths**

```bash
grep -n "docs/templates/" docs/hackweek/v1-implementation.md
```

Update any references from `docs/templates/review-tree.md` to `templates/review-tree.md` and `docs/templates/review-comments.md` to `templates/review-comments.md`.

- [ ] **Step 2: Commit**

```bash
git add docs/hackweek/v1-implementation.md
git commit -m "docs: fix template paths in hackweek v1-implementation.md"
```

---

## Chunk 3: Verification

### Task 8: Full path sweep

- [ ] **Step 1: Search for stale docs/ paths across the repo**

```bash
grep -r "docs/templates/" --include="*.md" --include="*.sh" --include="*.bats" . | grep -v "docs/private/" | grep -v "docs/hackweek/"
grep -r "docs/troubleshoot/" --include="*.md" --include="*.sh" --include="*.bats" . | grep -v "docs/private/"
grep -r "docs/plans/" --include="*.md" --include="*.sh" --include="*.bats" . | grep -v "docs/private/"
grep -r "docs/design/" --include="*.md" --include="*.sh" --include="*.bats" . | grep -v "docs/private/"
grep -r "docs/research/" --include="*.md" --include="*.sh" --include="*.bats" . | grep -v "docs/private/" | grep -v "docs/hackweek/"
grep -r "docs/superpowers/" --include="*.md" --include="*.sh" --include="*.bats" .
```

All greps should return empty (excluding private/ and hackweek/ which are historical artifacts left as-is per spec). Fix any hits found.

- [ ] **Step 2: Verify scripts don't hardcode docs/ paths**

```bash
grep -r "docs/" scripts/ tests/
```

Check any hits. Scripts reference templates via arguments, not hardcoded paths, but verify.

- [ ] **Step 3: Verify final directory structure**

```bash
find docs/ -type f -name "*.md" | sort
ls templates/ troubleshoot/
```

Compare against the spec's Target Structure.

- [ ] **Step 4: Fix any issues found and commit**

Fix any stale references found in Steps 1-2. Then:

```bash
git add -u  # only stage modified tracked files, not untracked
git commit -m "fix: resolve stale path references after docs reorganization"
```

Only commit this step if fixes were needed.

---

### Task 9: Update reconstruction decision record

**Files:**
- Modify: `docs/private/reconstruction/07-docs-reorganization-decision.md`

- [ ] **Step 1: Add implementation status**

Append to the end of `docs/private/reconstruction/07-docs-reorganization-decision.md`:

```markdown

## Implementation

Implemented 2026-03-14. See `docs/v1/2026-03-14-docs-reorganization-plan.md` for the execution plan and `docs/v1/2026-03-14-docs-reorganization-design.md` for the full spec.
```

- [ ] **Step 2: Commit**

```bash
git add docs/private/reconstruction/07-docs-reorganization-decision.md
git commit -m "docs: mark reorg decision as implemented"
```
