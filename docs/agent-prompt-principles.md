# Agent Prompt Principles

Evidence-based principles for writing effective agent prompts in Fowlcon. Derived from research on multi-agent orchestration, cognitive science, LLM behavioral studies, and production agent tools.

These principles apply to all prompts in `commands/` and `agents/`.

---

## 1. Agents Are Tools, Not Peers

Sub-agents receive a typed task, do their work, and return structured output. The orchestrator never sees their internal reasoning. No back-and-forth conversation between orchestrator and sub-agents.

**Why:** 2024-2025 evidence converges on agent-as-tool over agent-as-peer for orchestration. Anthropic's "Building Effective Agents" guide explicitly recommends structured output from sub-agents over conversational output. The peer model causes context window catastrophe -- a 10-turn investigation consumes 40k tokens in message history alone.

**In practice:**
- Concept researchers return a `FindingSet`, not a narrative
- The orchestrator synthesizes; sub-agents investigate
- Sub-agents are fire-and-forget with structured return

## 2. Constrain Output Format to Constrain Behavior

The strongest measured behavioral control is output format. Aider found that switching edit formats reduced GPT-4 Turbo "laziness" by 3x (score 20% → 61%). The Diff-XYZ benchmark confirms format choice dramatically affects output quality across models.

**Why:** When an agent must fill in required sections of a template, it cannot skip them. Format constraints convert behavioral requirements into structural requirements. The agent doesn't need to "want" to be thorough -- the template forces it.

**In practice:**
- Every agent prompt defines an exact output template with named sections
- Use required sections, not optional ones (`## Uncertainties` must always appear, even if empty)
- Provide 1-2 examples of correctly formatted output (few-shot)
- Schema validation (via `check-tree-quality.sh`) catches format violations mechanically

## 3. Negative Constraints Before Positive Instructions

State what the agent must NOT do before stating what it should do. The "documentarian mandate" (six DO NOT rules followed by one ONLY rule) appears at every tier in RPI and is the most reliable behavioral control pattern observed in production.

**Why:** LLMs trained with RLHF have strong refusal training -- they respond more reliably to prohibitions than permissions. A positive instruction ("be thorough") is vague. A negative constraint ("DO NOT summarize instead of showing detail") targets a specific failure mode.

**In practice:**
```markdown
## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN
- DO NOT suggest improvements
- DO NOT critique the implementation
- DO NOT identify "problems" or "issues"
- DO NOT recommend refactoring
- ONLY describe what exists and how it works
```

Place this block at the top of the prompt AND repeat key constraints at the bottom (primacy + recency positioning).

## 4. Name the Rationalizations

When you know how an agent will try to skip a step, name that rationalization explicitly in the prompt. A named anti-pattern is harder to use than an unnamed one.

**Why:** This pattern from Superpowers (the "red flags table") prevents agents from self-excusing non-compliance. By naming the exact thought ("This is simple enough to skip the tree") and providing the correction ("Build the tree anyway -- simple PRs still benefit from structure"), the agent recognizes its own rationalization attempt as a documented failure mode.

**In practice:**

For the orchestrator:
```markdown
## Red Flags -- If You Think This, Stop

| If you think... | The reality is... |
|---|---|
| "This PR is simple, skip the tree" | Simple PRs still benefit from structure. Build the tree. |
| "Coverage is close enough" | 100% or explain every gap. No exceptions. |
| "The pattern is obvious, skip examples" | Show at least one example. Obvious to you ≠ obvious to the reviewer. |
| "I can summarize instead of grouping" | Summaries lose detail. Group by concept. |
```

## 5. Mechanical Verification Over Self-Assessment

Never trust an agent's claim that it's done. Use external tools to verify completeness.

**Why:** LLMs cannot reliably self-assess completeness. The coverage bitmap pattern (checking coverage via script output rather than asking the agent "did you cover everything?") is strictly more reliable. Superpowers' "verification before completion" skill found 24 documented failure cases where agents claimed completion incorrectly.

**In practice:**
- Coverage completeness: checked by `coverage-report.sh`, not agent self-report
- Tree quality: checked by `check-tree-quality.sh`, not agent judgment
- File references: spot-checked by reading actual files, not trusting agent citations
- The orchestrator calls verification scripts BEFORE presenting results to the reviewer

## 6. One Agent, One Job

Each agent has a single, clearly-scoped responsibility. If an agent is doing two things, split it into two agents.

**Why:** Focused agents produce more reliable output than multi-purpose ones. Tool restrictions (Grep/Glob/LS only for the locator -- no Read) enforce specialization more reliably than instructions alone. CrewAI's known failure mode of "manager accepts incomplete output" is caused by agents with broad mandates.

**In practice:**
- `codebase-locator`: finds WHERE (no Read tool -- cannot analyze content)
- `codebase-analyzer`: explains HOW (has Read -- can analyze)
- `codebase-pattern-finder`: shows EXAMPLES (has Read -- returns code snippets)
- `coverage-checker`: verifies COMPLETENESS (Haiku -- mechanical check only)

## 7. Context Inline, Never File References

Sub-agents receive all context embedded in their prompt. Never pass a file path and expect the agent to read it.

**Why:** Sub-agents run in fresh context windows. They cannot access the orchestrator's context. Passing file paths creates a dependency on the agent successfully reading the file, which adds a failure mode. Inline context is guaranteed to be seen.

**In practice:**
- The orchestrator reads the diff, then embeds relevant hunks in the sub-agent's prompt
- PR metadata (title, description, file list) is pasted inline, not referenced
- The review tree (if it exists) is included as text, not as a path to read

## 8. Respect the Tree Structure Limits

The review tree has evidence-based structural constraints derived from cognitive load research.

**Why:** Miller's 7±2 (strategic capacity with labels) and Cowan's 4±1 (raw working memory) bound what reviewers can hold in mind. Hierarchy research shows 2-3 levels is optimal; performance degrades consistently at 4+ levels. The 3-5 children per node range matches chunking theory.

**In practice:**
- Top-level concepts: 7 hard max, 5-6 preferred
- Tree depth: 2-3 levels (4 only as documented exception)
- Children per node: 3-5 preferred, 2-7 acceptable, never 1 or 8+
- Single-child nodes are a structural smell -- collapse them
- Labels must be descriptive functional names, not "Other" or "Miscellaneous"
- `check-tree-quality.sh` enforces these limits

## 9. Use Unified Diff Format for Agent Consumption

When passing diff content to agents, use unified diff format with context lines and without line numbers in hunk headers.

**Why:** The Diff-XYZ benchmark (Oct 2025) found unified diff is the best format for LLM Apply and Anti-Apply tasks. Aider found omitting line numbers from hunk headers improves performance -- agents use context lines for matching, not line numbers. Including 3-5 context lines helps agents understand what surrounds the change.

**In practice:**
- Pass unified diff hunks to concept researchers
- Strip hunk header line numbers (`@@ -X,Y +A,B @@` → `@@`)
- Include surrounding context lines (unchanged code)
- Chunk by semantic unit (function/class) not by minimal hunk

## 10. Design for Fresh Starts

Long sessions degrade. Design prompts and state management so the review can restart cleanly at any point.

**Why:** Microsoft research found 39% average degradation in multi-turn conversations. At 50% context utilization, quality drops measurably. Batching context into a fresh call restored 90%+ accuracy. The "Lost in the Middle" effect means mid-session findings are in the attention danger zone.

**In practice:**
- All state lives in files (`review-tree.md`, `review-comments.md`), not in conversation context
- A new session reads state files and continues from the last known position
- The orchestrator can restart at any phase boundary without losing work
- Front-load critical instructions in the prompt (primacy positioning)
- Repeat key constraints at the end of the prompt (recency positioning)
- After processing sub-agent findings, commit to disk and drop from context

## 11. Supervisor Mode for Parallel Agents

When spawning multiple agents in parallel, use supervisor mode: capture failures as data, not exceptions.

**Why:** Structured concurrency research shows that fail-fast (abort everything when one agent fails) is wrong for research tasks where agents are independently valuable. Supervisor mode lets 2 of 3 successful agents' findings be used even if the third fails. The orchestrator marks the failed area as `[pending]` and the coverage checker catches the gap.

**In practice:**
- Concept researchers run in parallel with independent scopes
- If one fails: log the failure, mark the concept area as pending, continue
- If one returns low-quality output: flag for human investigation, don't silently include
- The coverage checker runs AFTER all agents complete (including failed ones) to identify gaps
- Retry failed agents with simplified prompts before giving up

## 12. The Reviewer Is the Protagonist

The tool serves the reviewer. It never makes decisions for them, never recommends approve/reject, and never hides information.

**Why:** Automation bias research shows 59% of developers use AI code they don't fully understand. Higher AI quality paradoxically increases complacency (2.5x more likely to merge without review). The "documentarian" pattern -- facts not recommendations -- is an anti-automation-bias design. When the tool organizes and explains rather than judges, the reviewer must engage their own judgment.

**In practice:**
- Agents describe what code does, never whether it's good or bad
- The orchestrator presents findings, never recommends a verdict
- Comments are captured as the reviewer's words, not the agent's suggestions
- "I get it!" is the reviewer's active choice, not the agent's assumption
- Complexity warnings are factual ("7 interleaving concepts across 50 files") not judgmental ("this PR is too complex")
