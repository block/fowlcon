# Fowlcon V1.0 Implementation Plan

**Goal:** Build the V1.0 core experience -- an agentic code review tool that analyzes a PR, builds a concept tree, and walks the reviewer through it conversationally.

**Architecture:** Markdown prompts (commands/ + agents/) with shell scripts for state management. The orchestrator (Opus) builds and owns the review tree, spawning Sonnet concept-researchers and workers for analysis. State lives in markdown files, writes go through shell scripts for reliability.

**Tech Stack:** Markdown prompts (YAML frontmatter), Bash shell scripts, bats-core (testing)

**Test Benchmark:** Hawksbury sample fixtures (32 files, 5 concepts with nested variations)

**End-of-task checklist (applies to EVERY task):**
1. **Verify:** Run tests, smoke tests, or manual checks as specified in the task. Confirm everything passes.
2. **Document:** Update or create documentation for what was built. At minimum: a brief comment in the file explaining its purpose, and an update to the repo README if the task adds a user-facing component. For formats and scripts, document the interface (inputs, outputs, expected behavior).
3. **Commit:** Stage and commit with a descriptive message.

---

## Phase 1: Foundation (Formats + Scripts) -- COMPLETED

The review-tree.md format was the critical-path decision. Everything else depends on it.

### Task 1: Design review-tree.md format -- COMPLETED

Format designed and approved. Key decisions:
- Two node types: concept (default) and variation (`{variation}` with `{repeat}` children)
- `context:` blocks on any node (the tour guide's voice, stored for resumability)
- `files:` on leaf nodes only, per-hunk entries with line ranges (`L<start>-<end>`)
- Coverage propagates upward; hunks can appear in multiple concepts (at-least-once)
- Dot-separated numeric IDs with no depth limit
- Description verification as table only, not tree nodes

**Files:** `docs/templates/review-tree.md`, `tests/formats/sample-tree-hawksbury.md`

---

### Task 2: Design review-comments.md format -- COMPLETED

Format designed and approved. Key decisions:
- GitHub API field names adopted directly (`side`, `line`, `type`)
- `side` field in V1.0 for forward-compatibility with V1.1 posting
- Diff hunk context NOT needed (modern line/side API doesn't need hunk headers)
- Source provenance field, soft deletion via status, tree revision tracking
- 43 tests across 2 suites

**Files:** `docs/templates/review-comments.md`, `tests/formats/sample-comments-hawksbury.md`, `tests/formats/sample-comments-edge-cases.md`

---

### Task 2.5: Tree parsing tests and CI -- COMPLETED

Added parsing tests for review-tree.md and GitHub Actions CI.

---

### Task 3: Shell script -- update node status -- COMPLETED

`scripts/update-node-status.sh` -- finds node by ID, updates status marker, writes atomically (temp file + mv). Validates status is one of: pending, reviewed, accepted. 26 tests.

---

### Task 4: Shell script -- add comment -- COMPLETED

`scripts/add-comment.sh` -- captures comments with full metadata, cross-file {comment} flag updates, content validation. 23 tests.

---

### Task 5: Shell script -- coverage report -- COMPLETED

`scripts/coverage-report.sh` -- read-only summary: status counts, confidence breakdown, pending list. 14 tests.

---

### Task 6: Tree quality checker -- COMPLETED

`scripts/check-tree-quality.sh` -- structural validation: 6 checks (HEAD, Revision, Desc Verification, top-level count, file coverage, variation structure). 14 tests.

---

## Phase 2: Worker Agents

Based on established sub-agent patterns, adapted for Fowlcon's PR context. Workers are restricted to read-only tools (no Bash) -- the concept-researcher handles version discovery and routing decisions.

### Task 7: Write worker agent prompts

**Files:**
- Create: `agents/codebase-locator.md`
- Create: `agents/codebase-analyzer.md`
- Create: `agents/codebase-pattern-finder.md`

**Step 1: Write codebase-locator.md**

YAML frontmatter with name, description, tools (Grep, Glob, LS), model (sonnet). Adapt for PR review context -- the locator finds files relevant to a concept within a PR. Documentarian role: find and report, never critique.

**Step 2: Write codebase-analyzer.md**

Tools: Read, Grep, Glob, LS. Model: sonnet. Documentarian role -- describe, never critique. Traces change boundaries (what connects to the changed code). Returns file:line references.

**Step 3: Write codebase-pattern-finder.md**

Tools: Grep, Glob, Read, LS. Model: sonnet. Finds similar patterns and examples. Adapted to find repetitive patterns within the PR diff (key for collapsing mechanical changes into variation nodes).

**Step 4: Smoke test each agent**

Test each by spawning with a specific question against a real codebase:
- Locator: "Find all files that import [specific class]"
- Analyzer: "Explain how [method] works"
- Pattern-finder: "Find the pattern used when [repeated change] is applied"

Verify output is structured, factual, and includes file:line references.

**Step 5: Commit**

```bash
git add agents/codebase-locator.md agents/codebase-analyzer.md agents/codebase-pattern-finder.md
git commit -m "feat: add worker agent prompts"
```

---

### Task 8: Write coverage-checker agent prompt

**Files:**
- Create: `agents/coverage-checker.md`

**Step 1: Write the prompt**

YAML frontmatter: name, description, tools (Grep, Glob, LS), model (haiku). Receives a file list (from PR diff) and a review-tree.md. Reports unmapped lines. Does NOT categorize -- just finds gaps. The orchestrator (Opus) decides whether gaps are mechanical/generated or require human mapping.

**Step 2: Smoke test**

Give it the Hawksbury file list and sample tree. Verify it correctly reports all files are mapped (or identifies gaps).

**Step 3: Commit**

```bash
git add agents/coverage-checker.md
git commit -m "feat: add coverage-checker agent prompt"
```

---

## Phase 3: Concept Researcher

### Task 9: Write concept-researcher agent prompt

**Files:**
- Create: `agents/concept-researcher.md`

**Step 1: Write the prompt**

YAML frontmatter: name, description, tools (Read, Grep, Glob, LS, Task, WebSearch, WebFetch), model (sonnet). Receives question + PR context inline (never file references). Spawns workers for mechanical tasks, synthesizes findings. Returns structured output: Concept, Summary, Findings (with file:line refs), Relevant Context, Change Boundary, Uncertainties.

The researcher discovers version context (runs `git rev-parse HEAD` via Bash if needed through the orchestrator) and provides it to workers in their prompts. Workers don't need to discover versions themselves.

**Step 2: Test against a real codebase**

Spawn with a conceptual question about a PR. Verify:
- Output follows the structured format
- File:line references are present
- Workers were spawned appropriately
- Change boundary is traced (imports, callers, interfaces)
- Uncertainties section is present (even if empty)

**Step 3: Test with a pattern-recognition question**

Spawn with: "What are the different patterns used for [a repeated change]?"

Verify it identifies distinct variations.

**Step 4: Commit**

```bash
git add agents/concept-researcher.md
git commit -m "feat: add concept-researcher agent prompt"
```

---

## Phase 4: Orchestrator

The orchestrator drives the entire review flow. This is the bulk of the work.

### Task 10: Write orchestrator prompt -- analysis phase

**Files:**
- Create: `commands/review_pr.md`

**Step 1: Write the prompt header and analysis phase**

YAML frontmatter: name (review-pr), description, model (opus). The prompt covers:
- Agent role statement (relentless quality advocate)
- Startup: read user-hints.md, check for existing per-PR data
- Fetch PR diff + description + metadata
- Spawn concept-researchers (as few passes as needed, maximum 3)
- Build the review tree using the format from `docs/templates/review-tree.md`
- Verify description against tree
- Run coverage checker
- Evaluate complexity (7 top-level threshold, based on Miller's 7±2)
- Anti-rationalization instructions
- Respect repository convention files (CLAUDE.md, AGENTS.md, etc.)

Write only the analysis phase first. The walkthrough phase comes in Task 11.

**Step 2: Test analysis against a real PR**

Run `/review-pr` with a PR URL. Let it analyze and build the tree. Evaluate:
- Does it produce a reasonable number of concepts?
- Are repetitive patterns collapsed into variation nodes?
- Are description claims verified?
- Is coverage complete?
- Does the tree quality checker pass?

**Step 3: Iterate on the prompt**

Refine based on test results. Watch for:
- Agent summarizing instead of grouping (anti-rationalization)
- Missing important pattern distinctions
- Not tracing dependency injection or framework patterns
- Overcounting or undercounting files

**Step 4: Commit**

```bash
git add commands/review_pr.md
git commit -m "feat: add orchestrator prompt -- analysis phase"
```

---

### Task 11: Write orchestrator prompt -- walkthrough phase

**Files:**
- Modify: `commands/review_pr.md`

**Step 1: Add walkthrough phase to the orchestrator prompt**

Extend the prompt with:
- Present tree to customer, handle complexity discussion
- Hierarchical tree traversal (depth-first)
- Customer responses: reviewed, comment, go back
- "I get it! Accept the rest." short-circuit → accepted
- Accept all for pattern instances
- Jumping (navigate to any node, unvisited stay pending)
- Comment capture (call add-comment.sh with full metadata)
- Status updates (call update-node-status.sh)
- Adaptive pacing (read the room, don't ask "how familiar are you?")
- Summary generation (on-the-fly from tree via coverage-report.sh)
- Memory update proposals (transparent, customer-approved)
- Fresh start command handling

**Step 2: Test walkthrough**

After analysis produces a tree, walk through the review:
- Review the core new code in detail (concept 1)
- "I get it!" on a repetitive pattern (concept 2)
- Walk through one variation example, accept rest (concept 3)
- Review remaining concepts
- Ask for summary
- Verify all state is saved to review-tree.md and review-comments.md

**Step 3: Test resumability**

Exit the session. Start a new session with the same PR. Verify:
- Orchestrator finds existing data store
- Offers to resume
- Picks up from the right place based on review-tree.md status

**Step 4: Iterate and commit**

```bash
git add commands/review_pr.md
git commit -m "feat: add orchestrator prompt -- walkthrough phase"
```

---

### Task 12: Write orchestrator prompt -- preconditions and troubleshooting

**Files:**
- Modify: `commands/review_pr.md`

**Step 1: Add precondition handling**

Extend the prompt with:
- At startup, read user-hints.md
- Optimistic -- try to fetch PR, if it fails load the relevant troubleshooting guide
- Reference troubleshoot/pr-access.md, troubleshoot/repo-access.md
- Propose hints to customer after resolution

**Step 2: Test with a repo that needs troubleshooting**

Try a PR in a repo where the default diff method fails (e.g., a large PR that truncates, or a repo not cloned locally). Verify the orchestrator loads the troubleshooting guide and follows the fallback chain.

**Step 3: Commit**

```bash
git add commands/review_pr.md
git commit -m "feat: add orchestrator precondition handling"
```

---

## Phase 5: Detector + Install

### Task 13: Write detector skill

**Files:**
- Create: `skills/detect-pr-context.md` (or appropriate location for the platform)

**Step 1: Write the detector prompt**

Trigger signals:
- Explicit review language ("review this PR," "check this diff") + URL
- PR URL as first interaction in a new session (strong intent signal)
- Branch with open PR + review mention
- Weak signal: mid-conversation URL (use context to decide)

Behavior: one gentle offer per PR per session. Never pushy.

**Step 2: Test triggering**

Test with prompts:
- "Review this PR: https://github.com/..." → should trigger
- (first message) "https://github.com/.../pull/123" → should trigger
- "I was looking at https://github.com/.../pull/123 for context on a bug" → should use context

**Step 3: Commit**

```bash
git add skills/detect-pr-context.md
git commit -m "feat: add PR context detector skill"
```

---

### Task 14: Write install script

**Files:**
- Create: `scripts/install`

**Step 1: Write the install script**

The script:
- Copies agent files to `~/.claude/agents/`
- Copies command files to `~/.claude/commands/`
- Copies scripts to an accessible location
- Creates `~/.code-review-agent/` if it doesn't exist
- Seeds `user-hints.md` from template if it doesn't exist
- Handles updates (prompt for overwrite)
- Supports custom install path

**Step 2: Test installation**

Run install to a temp directory. Verify all files land in the right places. Verify user-hints.md is seeded correctly.

**Step 3: Commit**

```bash
git add scripts/install
git commit -m "feat: add install script"
```

---

## Phase 6: Integration Testing

### Task 15: End-to-end test -- small PR

Find a small public PR (5-10 files, focused change). Run the full flow:
1. `/review-pr <url>`
2. Let analysis complete
3. Walk through the tree
4. Add a comment
5. Review summary
6. Verify all state files are correct

Document results and any issues found.

---

### Task 16: End-to-end test -- medium PR

Find a medium public PR (20-50 files, multiple concepts). Run the full flow. Verify:
- Multiple concepts identified
- Patterns collapsed where appropriate
- Description verification works
- "I get it!" short-circuit works correctly

Document results and any issues found.

---

### Task 17: End-to-end test -- large mechanical PR

Find a large public PR with repetitive mechanical changes (100+ files). This is the benchmark. Verify:
- Many files collapse into few concepts
- Variation nodes correctly identified
- Exclusions are noted
- Description claims are verified
- Tree quality checker passes
- Walkthrough is manageable
- Performance is acceptable (benchmark the analysis phase)

Document results. This is the demo-quality test case.

---

## Phase 7: Documentation + Release

### Task 18: Final documentation pass

**Step 1: Update README**

Ensure README reflects the actual shipped state (not aspirational features). Update architecture diagram, installation instructions, and usage examples based on what was actually built.

**Step 2: Attribution review**

- Credit open source projects that inspired patterns (see Acknowledgments in README)
- Verify LICENSE file is correct
- Ensure CONTRIBUTING.md is current

**Step 3: Final commit**

```bash
git add -A
git commit -m "docs: final documentation pass for V1.0"
```
